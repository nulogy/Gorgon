require "gorgon/worker"
require "gorgon/g_logger"
require 'gorgon/callback_handler'
require 'gorgon/pipe_manager'
require 'gorgon/job_definition'

require 'eventmachine'

class WorkerManager
  include PipeManager
  include GLogger

  def self.build listener_config_file
    @listener_config_file = listener_config_file
    config = Configuration.load_configuration_from_file(listener_config_file)

    new config
  end

  def initialize config
    initialize_logger config[:log_file]
    log "Worker Manager #{Gorgon::VERSION} initialize"

    @worker_pids = []

    @config = config

    payload = Yajl::Parser.new(:symbolize_keys => true).parse($stdin.read)
    @job_definition = JobDefinition.new(payload)

    @callback_handler = CallbackHandler.new(@job_definition.callbacks)
    @available_worker_slots = config[:worker_slots]

    connect
  end

  def manage
    fork_workers @available_worker_slots
  end

  private

  def connect
    @bunny = Bunny.new(@config[:connection])
    @bunny.start
    @reply_exchange = @bunny.exchange(@job_definition.reply_exchange_name)

    @originator_queue = @bunny.queue("", :exclusive => true, :auto_delete => true)
    exchange = @bunny.exchange("gorgon.worker_managers", :type => :fanout)
    @originator_queue.bind(exchange)
  end

  def fork_workers n_workers
    log "Running before_creating_workers callback"
    @callback_handler.before_creating_workers

    log "Forking #{n_workers} worker(s)"
    EventMachine.run do
      n_workers.times do
        fork_a_worker
      end

      subscribe_to_originator_queue
    end
  end

  def fork_a_worker
    @available_worker_slots -= 1
    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename

    pid, stdin, stdout, stderr = pipe_fork_worker
    @worker_pids << pid
    stdin.write(@job_definition.to_json)
    stdin.close

    watcher = proc do
      ignore, status = Process.waitpid2 pid
      @worker_pids.delete(pid)
      log "Worker #{pid} finished"
      status
    end

    worker_complete = proc do |status|
      if status.exitstatus != 0
        log_error "Worker #{pid} crashed with exit status #{status.exitstatus}!"
        error_msg = stderr.read
        log_error "ERROR MSG: #{error_msg}"

        # originator may have cancel job and exit, so only try to send message
        begin
          reply = {:type => :crash,
            :hostname => Socket.gethostname,
            :stdout => stdout.read,
            :stderr => error_msg}
          @reply_exchange.publish(Yajl::Encoder.encode(reply))
          # TODO: find a way to stop the whole system when a worker crashes or do something more clever
        rescue Exception => e
          log_error "Exception raised when trying to report crash to originator:"
          log_error e.message
          log_error e.backtrace.join("\n")
        end
      end
      on_worker_complete
    end
    EventMachine.defer(watcher, worker_complete)
  end

  def on_worker_complete
    @available_worker_slots += 1
    on_current_job_complete if current_job_complete?
  end

  def current_job_complete?
    @available_worker_slots == @config[:worker_slots]
  end

  def on_current_job_complete
    log "Job '#{@job_definition.inspect}' completed"

    stop
  end

  def stop
    EventMachine.stop_event_loop
    @bunny.stop
  end

  CANCEL_TIMEOUT = 15
  def subscribe_to_originator_queue

    originator_watcher = proc do
      while true
        if (payload = @originator_queue.pop[:payload]) != :queue_empty
          break
        end
        sleep 0.5
      end
      Yajl::Parser.new(:symbolize_keys => true).parse(payload)
    end

    handle_message = proc do |payload|
      if payload[:action] == "cancel_job"
        log "Cancel job received!!!!!!"

        log "Sending 'INT' signal to #{@worker_pids}"
        Process.kill("INT", *@worker_pids)
        log "Signal sent"

        EM.add_timer(CANCEL_TIMEOUT) { stop }
      else
        EventMachine.defer(originator_watcher, handle_message)
      end
    end

    EventMachine.defer(originator_watcher, handle_message)
  end
end
