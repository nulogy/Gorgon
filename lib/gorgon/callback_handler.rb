class CallbackHandler
  def initialize(config)
    @config = config || {}
    # MY_NOTE: Rename temp_callbacks after legacy callbacks use new way
    load(@config[:temp_callbacks]) if @config[:temp_callbacks]
  end

  def before_originate
    cluster_id = Gorgon.callbacks.before_originate
    return cluster_id if cluster_id.is_a?(String)
  end

  def after_sync
    Gorgon.callbacks.after_sync
  end

  def before_creating_workers
    Gorgon.callbacks.before_creating_workers
  end

  def before_start
    Gorgon.callbacks.before_start
  end

  def after_creating_workers
    Gorgon.callbacks.after_creating_workers
  end

  def after_complete
    Gorgon.callbacks.after_complete
  end

  def after_job_finishes
    Gorgon.callbacks.after_job_finishes
>>>>>>> WIP
  end
end
