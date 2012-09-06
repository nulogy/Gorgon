class WorkerManager
  def self.build listener_config_file
    config = Configuration.load_configuration_from_file(listener_config_file)

    new config
  end

  def initialize config
    @config = config
    payload = Yajl::Parser.new(:symbolize_keys => true).parse($stdin.read)
    @job_definition = JobDefinition.new(payload)

    @callback_handler = CallbackHandler.new(config[:callback_handler])
    @available_worker_slots = config[:worker_slots]
  end

  def manage
    fork_workers @available_worker_slots
  end

  private

  def fork_workers n_workers

  end
end
