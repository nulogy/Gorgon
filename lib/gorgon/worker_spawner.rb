class WorkerSpawner
  include Configuration

  def self.build(config_filename)
    config = Configuration.load_configuration_from_file(config_filename)
    new config
  end

  def initialize config
    @config = config
    @callback_handler = CallbackHandler.new(config[:callback_handler])
  end

  def spawn n_workers
    @callback_handler.before_creating_workers
    n_workers.times do
      fork_a_worker
    end
  end

  private

  def fork_a_worker
    fork do
      w = Worker.build(@config)
      w.work

      exit
    end
  end
end
