require "gorgon/job_definition"
require "gorgon/configuration"
require "gorgon/worker"

require "yajl"
require "bunny"
require "awesome_print"
require "open4"
require "tmpdir"
require "socket"
require "logger"

class Listener
  include Configuration

  def initialize
    @listener_config_filename = Dir.pwd + "/gorgon_listener.json"
    @available_worker_slots = configuration[:worker_slots]
    initialize_logger

    log "Listener initialized"
    connect
    initialize_personal_job_queue
  end

  def listen
    log "Waiting for jobs..."
    while true
      sleep 10 unless poll
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

    start_job(message[:payload])
    return true
  end

  def start_job(json_payload)
    log "Job received: #{json_payload}"
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(json_payload)
    @job_definition = JobDefinition.new(payload)
    @reply_exchange = @bunny.exchange(@job_definition.reply_exchange_name)

    copy_source_tree(@job_definition.source_tree_path)
    fork_worker_manager
  end

  def fork_worker_manager
    log "Forking Worker Manager"

    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename
    pid, stdin, stdout, stderr = Open4::popen4 "gorgon manage_workers"
    stdin.write(@job_definition)
    stdin.close

    ignore, status = Process.waitpid2 pid
    log "Worker Manager #{pid} finished"

    if status.exitstatus != 0
      log_error "Worker Manager #{pid} crashed with exit status #{status.exitstatus}!"
      reply = {:type => :crash,
        :hostname => Socket.gethostname,
        :stdout => stdout.read,
        :stderr => stderr.read}
      @reply_exchange.publish(Yajl::Encoder.encode(reply))
    end
  end

  def on_worker_complete
    @available_worker_slots += 1
    on_current_job_complete if current_job_complete?
  end

  def current_job_complete?
    @available_worker_slots == configuration[:worker_slots]
  end

  def on_current_job_complete
    log "Job '#{@job_definition.inspect}' completed"
    FileUtils::remove_entry_secure(@tempdir)
    EventMachine.stop_event_loop
  end

  def connection_information
    configuration[:connection]
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon_listener.json")
  end

private

  def copy_source_tree source_tree_path
    @tempdir = Dir.mktmpdir("gorgon")
    Dir.chdir(@tempdir)
    system("rsync -r --rsh=ssh #{source_tree_path}/* .")

    if ($?.exitstatus == 0)
      log "Syncing completed successfully."
    else
      #TODO handle error:
      # - Discard job
      # - Let the originator know about the error
      # - Wait for the next job
      log_error "Command 'rsync -r --rsh=ssh #{@job_definition.source_tree_path}/* .' failed!"
    end
  end

  def initialize_logger
    return unless configuration[:log_file]
    @logger =
      if configuration[:log_file] == "-"
        Logger.new($stdout)
      else
        Logger.new(configuration[:log_file])
      end
    @logger.datetime_format = "%Y-%m-%d %H:%M:%S "
  end

  def log text
    @logger.info(text) if @logger
  end

  def log_error text
    @logger.error(text) if @logger
  end
end
