require "gorgon/worker"
require "gorgon/g_logger"
require 'gorgon/callback_handler'
require 'gorgon/pipe_manager'
require 'gorgon/job_definition'
require 'gorgon/source_tree_syncer'

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

    @config = config

    payload = Yajl::Parser.new(:symbolize_keys => true).parse($stdin.read)
    @job_definition = JobDefinition.new(payload)

    @callback_handler = CallbackHandler.new(@job_definition.callbacks)
    @available_worker_slots = config[:worker_slots]

    bunny = Bunny.new(config[:connection])
    bunny.start
    @reply_exchange = bunny.exchange(@job_definition.reply_exchange_name)
  end

  def manage
    copy_source_tree(@job_definition.source_tree_path, @job_definition.sync_exclude)
    fork_workers @available_worker_slots
  end

  private

  def copy_source_tree source_tree_path, exclude
    syncer = SourceTreeSyncer.new source_tree_path
    syncer.exclude = exclude
    syncer.sync
  end

  def fork_workers n_workers
    log "Running before_creating_workers callback"
    @callback_handler.before_creating_workers

    log "Forking #{n_workers} worker(s)"
    EventMachine.run do
      n_workers.times do
        fork_a_worker
      end
    end
  end

  def fork_a_worker
    @available_worker_slots -= 1
    ENV["GORGON_CONFIG_PATH"] = @listener_config_filename

    pid, stdin, stdout, stderr = pipe_fork_worker
    stdin.write(@job_definition.to_json)
    stdin.close

    watcher = proc do
      ignore, status = Process.waitpid2 pid
      log "Worker #{pid} finished"
      status
    end

    worker_complete = proc do |status|
      if status.exitstatus != 0
        log_error "Worker #{pid} crashed with exit status #{status.exitstatus}!"
        error_msg = stderr.read
        log_error "ERROR MSG: #{error_msg}"

        reply = {:type => :crash,
          :hostname => Socket.gethostname,
          :stdout => stdout.read,
          :stderr => error_msg}
        @reply_exchange.publish(Yajl::Encoder.encode(reply))
        # TODO: find a way to stop the whole system when a worker crashes or do something more clever
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
    FileUtils::remove_entry_secure(@tempdir)
    EventMachine.stop_event_loop
  end
end
