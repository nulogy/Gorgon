require "gorgon/worker"
require "gorgon/g_logger"
require 'gorgon/callback_handler'
require 'gorgon/pipe_forker'
require 'gorgon/job_definition'
require "gorgon/crash_reporter"

require 'eventmachine'

class WorkerManager
  include PipeForker
  include GLogger
  include CrashReporter

  STDOUT_FILE='/tmp/gorgon-worker-mgr.out'
  STDERR_FILE='/tmp/gorgon-worker-mgr.err'

  def self.build listener_config_file
    @listener_config_file = listener_config_file
    config = Configuration.load_configuration_from_file(listener_config_file)

    redirect_output_to_files

    new config
  end

  def self.redirect_output_to_files
    STDOUT.reopen(File.open(STDOUT_FILE, 'w'))
    STDOUT.sync = true

    STDERR.reopen(File.open(STDERR_FILE, 'w'))
    STDERR.sync = true
  end

  def initialize config
    initialize_logger config[:log_file]
    log "Worker Manager #{Gorgon::VERSION} initializing"

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
    @bunny = GorgonBunny.new(@config[:connection])
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
    @callback_handler.after_creating_workers
  end

  def fork_a_worker
    @available_worker_slots -= 1
    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename

    worker_id = get_worker_id
    log "Forking Worker #{worker_id}"
    pid, stdin = pipe_fork do
      worker = Worker.build(worker_id, @config)
      worker.work
    end

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
        exitstatus = status.exitstatus
        log_error "Worker #{pid} crashed with exit status #{exitstatus}!"

        # originator may have cancel job and exit, so only try to send message
        begin
          out_file = Worker.output_file(worker_id, :out)
          err_file = Worker.output_file(worker_id, :err)

          msg = report_crash @reply_exchange, :out_file => out_file,
          :err_file => err_file, :footer_text => footer_text(err_file, out_file)
          log_error "Process output:\n#{msg}"

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

  def get_worker_id
    @worker_id_count = @worker_id_count.nil? ? 1 : @worker_id_count + 1
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

  CANCEL_TIMEOUT = 20
  def subscribe_to_originator_queue

    originator_watcher = proc do
      payload = nil
      while true
        response = @originator_queue.pop
        if response != [nil, nil, nil]
          payload = response[2]
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

  def footer_text err_file, out_file
    "\n***** See #{err_file} and #{out_file} at '#{Socket.gethostname}' for complete output *****\n"
  end
end
