require "gorgon/job_definition"
require "gorgon/configuration"
require 'gorgon/source_tree_syncer'
require "gorgon/g_logger"
require "gorgon/callback_handler"

require "yajl"
require "bunny"
require "awesome_print"
require "open4"
require "tmpdir"
require "socket"

class Listener
  include Configuration
  include GLogger

  def initialize
    @listener_config_filename = Dir.pwd + "/gorgon_listener.json"
    initialize_logger configuration[:log_file]

    log "Listener initialized"
    connect
    initialize_personal_job_queue
  end

  def listen
    log "Waiting for jobs..."
    while true
      sleep 1 unless poll
    end
  end

  def connect
    @bunny = Bunny.new(connection_information)
    @bunny.start
  end

  def initialize_personal_job_queue
    @job_queue = @bunny.queue("", :exclusive => true)
    exchange = @bunny.exchange("gorgon.jobs", :type => :fanout)
    @job_queue.bind(exchange)
  end

  def poll
    message = @job_queue.pop
    return false if message[:payload] == :queue_empty

    run_job(message[:payload])

    log "Waiting for more jobs..."
    return true
  end

  def run_job(json_payload)
    log "Job received: #{json_payload}"
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(json_payload)
    @job_definition = JobDefinition.new(payload)
    @reply_exchange = @bunny.exchange(@job_definition.reply_exchange_name)

    @callback_handler = CallbackHandler.new(@job_definition.callbacks)
    copy_source_tree(@job_definition.source_tree_path, @job_definition.sync_exclude)

    if !run_after_sync
      clean_up
      return
    end

    Bundler.with_clean_env do
      fork_worker_manager
    end

    clean_up
  end

  private

  def run_after_sync
    log "Running after_sync callback"
    begin
      @callback_handler.after_sync
    rescue Exception => e
      log_error "Exception raised when running after_sync callback_handler. Please, check your script in #{@job_definition.callbacks[:after_sync]}:"
      log_error e.message
      log_error "\n" + e.backtrace.join("\n")

      reply = {:type => :crash,
        :hostname => Socket.gethostname,
        :message => "after_sync callback failed. Please, check your script in #{@job_definition.callbacks[:after_sync]}. Message: #{e.message}",
        :backtrace => e.backtrace.join("\n")
      }
      @reply_exchange.publish(Yajl::Encoder.encode(reply))
      return false
    end
  end

  def copy_source_tree source_tree_path, exclude
    log "Downloading source tree to temp directory..."
    @syncer = SourceTreeSyncer.new source_tree_path
    @syncer.exclude = exclude
    if @syncer.sync
      log "Command '#{@syncer.sys_command}' completed successfully."
    else
      #TODO handle error:
      # - Discard job
      # - Let the originator know about the error
      # - Wait for the next job
      log_error "Command '#{@syncer.sys_command}' failed!"
    end
  end

  def clean_up
    @syncer.remove_temp_dir
  end

  def fork_worker_manager
    log "Forking Worker Manager"
    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename
    pid, stdin, stdout, stderr = Open4::popen4 "bundle exec gorgon manage_workers"
    stdin.write(@job_definition.to_json)
    stdin.close

    ignore, status = Process.waitpid2 pid
    log "Worker Manager #{pid} finished"

    if status.exitstatus != 0
      log_error "Worker Manager #{pid} crashed with exit status #{status.exitstatus}!"
      error_msg = stderr.read
      log_error "ERROR MSG: #{error_msg}"

      reply = {:type => :crash,
        :hostname => Socket.gethostname,
        :stdout => stdout.read,
        :stderr => error_msg}
      @reply_exchange.publish(Yajl::Encoder.encode(reply))
    end
  end

  def connection_information
    configuration[:connection]
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon_listener.json")
  end
end
