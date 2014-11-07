class CallbackHandler
  def initialize(config)
    @config = config || {}
    load(@config[:temp_callbacks]) if @config[:temp_callbacks]
  end

  def before_job_starts
    Gorgon.callbacks.before_job_starts
  end

  def after_job_finishes
    Gorgon.callbacks.after_job_finishes
  end

  def before_start
    load_callback(:before_start)
  end

  def after_complete
    load_callback(:after_complete)
  end

  def before_creating_workers
    load_callback(:before_creating_workers)
  end

  def after_sync
    load_callback(:after_sync)
  end

  def after_creating_workers
    load_callback(:after_creating_workers)
  end

  def before_originate
    load_callback(:before_originate)
  end

  private

  def load_callback(name)
    load(@config[name]) if @config[name]
  end
end
