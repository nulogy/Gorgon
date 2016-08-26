require 'gorgon'
require 'gorgon/originator_protocol'
require 'gorgon/configuration'
require 'gorgon/job_state'
require 'gorgon/progress_bar_view'
require 'gorgon/originator_logger'
require 'gorgon/failures_printer'
require 'gorgon/source_tree_syncer'
require 'gorgon/shutdown_manager'
require 'gorgon/callback_handler'
require 'gorgon/runtime_recorder'
require 'gorgon/runtime_file_reader'

require 'awesome_print'
require 'etc'
require 'socket'

class Originator
  include Configuration

  def initialize
    @configuration = nil
  end

  def originate
    begin
      Signal.trap("INT") { ctrl_c }
      Signal.trap("TERM") { ctrl_c }

      publish
      @logger.log "Originator finished successfully"
    rescue StandardError
      $stderr.puts "Unhandled exception in originator:"
      $stderr.puts $!.message
      $stderr.puts $!.backtrace.join("\n")
      $stderr.puts "----------------------------------"
      $stderr.puts "Now attempting to cancel the job."
      @logger.log_error "Unhandled Exception!" if @logger
      cancel_job
      exit 2
    end
  end

  def cancel_job
    ShutdownManager.new(protocol: @protocol, job_state: @job_state).cancel_job
  end

  def ctrl_c
    puts "\nCtrl-C received! Just wait a moment while I clean up..."
    cancel_job
  end

  def publish
    @logger = OriginatorLogger.new configuration[:originator_log_file]

    if files.empty?
      $stderr.puts "There are no files to test! Quitting."
      exit 2
    end

    cluster_id = callback_handler.before_originate

    push_source_code

    @protocol = OriginatorProtocol.new(@logger, cluster_id)

    EventMachine.run do
      publish_files_and_job

      @protocol.receive_payloads do |payload|
        handle_reply(payload)
      end

      @protocol.receive_new_listener_notifications do |payload|
        handle_new_listener_notification(payload)
      end
    end

    callback_handler.after_job_finishes
  end

  def publish_files_and_job
    @logger.log "Connecting..."
    @protocol.connect connection_information, :on_closed => method(:on_disconnect)

    @logger.log "Publishing files..."
    @protocol.publish_files files
    create_job_state_and_observers

    @logger.log "Publishing Job..."
    @protocol.publish_job_to_all job_definition
    @logger.log "Job Published"
  end

  def callback_handler
    @callback_handler ||= CallbackHandler.new(configuration[:job][:callbacks])
  end

  def push_source_code
    syncer = SourceTreeSyncer.new(sync_configuration)
    syncer.push
    if syncer.success?
      @logger.log "Command '#{syncer.sys_command}' completed successfully."
    else
      $stderr.puts "Command '#{syncer.sys_command}' failed!"
      $stderr.puts "Stdout:\n#{syncer.output}"
      $stderr.puts "Stderr:\n#{syncer.errors}"
      exit 1
    end
  end

  def cleanup_if_job_complete
    if @job_state.is_job_complete?
      @logger.log "Job is done"
      @protocol.disconnect
    end
  end

  def handle_reply(payload)
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(payload)

    # at some point this will probably need to be fancy polymorphic type based responses, or at least a nice switch statement
    if payload[:action] == "finish"
      @job_state.file_finished payload
    elsif payload[:action] == "start"
      @job_state.file_started payload
    elsif payload[:type] == "crash"
      @job_state.gorgon_crash_message payload
    elsif payload[:type] == "exception"
      # TODO
      ap payload
    else
      ap payload
    end

    @logger.log_message payload
    # Uncomment this to see each message received by originator
    # ap payload

    cleanup_if_job_complete
  end

  def handle_new_listener_notification(payload)
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(payload)

    if payload[:listener_queue_name]
      @protocol.publish_job_to_one(job_definition, payload[:listener_queue_name])
    else
      puts "Received unexpected payload on originator queue"
      ap payload
    end
  end

  def create_job_state_and_observers
    @job_state = JobState.new files.count
    RuntimeRecorder.new @job_state, configuration[:runtime_file]
    @progress_bar_view = ProgressBarView.new @job_state
    @progress_bar_view.show
    FailuresPrinter.new(configuration, @job_state)
  end

  def on_disconnect
    EventMachine.stop
  end

  def connection_information
    configuration[:connection]
  end

  def files
    @files ||= RuntimeFileReader.new(configuration).sorted_files
  end

  def job_definition
    # TODO: remove duplication. Use sync_configuration
    job_config = configuration[:job]
    job_config[:sync] = {} unless job_config.has_key?(:sync)
    job_config[:sync][:source_tree_path] = source_tree_path(job_config[:sync])
    JobDefinition.new(configuration[:job])
  end

  private

  def sync_configuration
    configuration[:job].
      fetch(:sync, {}).
      merge(source_tree_path: source_tree_path(configuration[:job][:sync])
    )
  end

  def source_tree_path(sync_config)
    hostname = Socket.gethostname
    source_code_root = File.basename(Dir.pwd)

    if sync_config && sync_config[:rsync_transport] == SourceTreeSyncer::RSYNC_TRANSPORT_SSH
      "#{file_server_host}:#{hostname}_#{source_code_root}"
    else
      "rsync://#{file_server_host}:43434/src/#{hostname}_#{source_code_root}"
    end
  end

  def file_server_host
    if configuration[:file_server].nil?
      raise <<-MSG
        Missing file_server configuration.
        See https://github.com/Fitzsimmons/Gorgon/blob/master/gorgon.json.sample for a sample configuration
MSG
    end

    configuration[:file_server][:host]
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon.json")
  end
end
