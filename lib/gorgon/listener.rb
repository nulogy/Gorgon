require "gorgon/job_definition"
require "gorgon/configuration"
require 'gorgon/source_tree_syncer'
require "gorgon/g_logger"
require "gorgon/callback_handler"
require "gorgon/version"
require "gorgon/worker_manager"
require "gorgon/crash_reporter"
require "gorgon/gem_command_handler"
require 'gorgon/originator_protocol'

require "yajl"
require "gorgon_bunny/lib/gorgon_bunny"
require "awesome_print"
require "open4"
require "tmpdir"
require "socket"

class Listener
  include Configuration
  include GLogger
  include CrashReporter

  def initialize
    @listener_config_filename = Dir.pwd + "/gorgon_listener.json"
    initialize_logger configuration[:log_file]

    log "Listener #{Gorgon::VERSION} initializing"
    connect
    initialize_personal_job_queue
  end

  def listen
    at_exit_hook
    log "Waiting for jobs..."
    while true
      sleep 2 unless poll
    end
  end

  def connect
    @bunny = GorgonBunny.new(connection_information)
    @bunny.start
  end

  def initialize_personal_job_queue
    @job_queue = @bunny.queue("", :exclusive => true)
    exchange = @bunny.exchange(job_queue_name, :type => :fanout)
    @job_queue.bind(exchange)
  end

  def poll
    message = @job_queue.pop
    return false if message == [nil, nil, nil]
    log "Received: #{message}"

    payload = message[2]

    handle_request payload

    log "Waiting for more jobs..."
    return true
  end

  def handle_request json_payload
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(json_payload)

    case payload[:type]
    when "job_definition"
      run_job(payload)
    when "ping"
      respond_to_ping payload[:reply_exchange_name]
    when "gem_command"
      GemCommandHandler.new(@bunny).handle payload, configuration
    end
  end

  def run_job(payload)
    @job_definition = JobDefinition.new(payload)
    @reply_exchange = @bunny.exchange(@job_definition.reply_exchange_name, :auto_delete => true)

    copy_source_tree(@job_definition.sync)

    if !@syncer.success? || !run_after_sync
      clean_up
      return
    end

    fork_worker_manager

    clean_up
  end

  def at_exit_hook
    at_exit { log "Listener will exit!"}
  end

  private

  def run_after_sync
    log "Running after_sync callback..."
    begin
      callback_handler.after_sync
    rescue Exception => e
      log_error "Exception raised when running after_sync callback_handler. Please, check your script in #{@job_definition.callbacks[:after_sync]}:"
      log_error e.message
      log_error "\n" + e.backtrace.join("\n")

      reply = {:type => :exception,
        :hostname => Socket.gethostname,
        :message => "after_sync callback failed. Please, check your script in #{@job_definition.callbacks[:after_sync]}. Message: #{e.message}",
        :backtrace => e.backtrace.join("\n")
      }
      @reply_exchange.publish(Yajl::Encoder.encode(reply))
      return false
    end
    true
  end

  def callback_handler
    @callback_handler ||= CallbackHandler.new(@job_definition.callbacks)
  end

  def copy_source_tree(sync_configuration)
    log "Downloading source tree to temp directory..."
    @syncer = SourceTreeSyncer.new sync_configuration
    @syncer.sync
    if @syncer.success?
      log "Command '#{@syncer.sys_command}' completed successfully."
    else
      send_crash_message @reply_exchange, @syncer.output, @syncer.errors
      log_error "Command '#{@syncer.sys_command}' failed!"
      log_error "Stdout:\n#{@syncer.output}"
      log_error "Stderr:\n#{@syncer.errors}"
    end
  end

  def clean_up
    @syncer.remove_temp_dir
  end

  ERROR_FOOTER_TEXT = "\n***** See #{WorkerManager::STDERR_FILE} and #{WorkerManager::STDOUT_FILE} at '#{Socket.gethostname}' for complete output *****\n"
  def fork_worker_manager
    log "Forking Worker Manager..."
    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename

    pid, stdin = Open4::popen4 "gorgon manage_workers"
    stdin.write(@job_definition.to_json)
    stdin.close

    _, status = Process.waitpid2 pid
    log "Worker Manager #{pid} finished"

    if status.exitstatus != 0
      exitstatus = status.exitstatus
      log_error "Worker Manager #{pid} crashed with exit status #{exitstatus}!"

      msg = report_crash @reply_exchange, :out_file => WorkerManager::STDOUT_FILE,
      :err_file => WorkerManager::STDERR_FILE, :footer_text => ERROR_FOOTER_TEXT

      log_error "Process output:\n#{msg}"
    end
  end

  def respond_to_ping reply_exchange_name
    reply = {:type => "ping_response", :hostname => Socket.gethostname,
      :version => Gorgon::VERSION, :worker_slots => configuration[:worker_slots]}
    publish_to reply_exchange_name, reply
  end

  def publish_to reply_exchange_name, message
    reply_exchange = @bunny.exchange(reply_exchange_name, :auto_delete => true)

    log "Sending #{message}"
    reply_exchange.publish(Yajl::Encoder.encode(message))
  end

  def job_queue_name
    OriginatorProtocol.job_queue_name(configuration.fetch(:cluster_id, nil))
  end

  def connection_information
    configuration[:connection]
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon_listener.json")
  end
end
