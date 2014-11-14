module Gorgon
  class DefaultCallbacks
    # @return cluster id. Cluster id is used to identify the queue in RabbitMQ
    def before_originate
    end

    def after_sync
    end

    def before_creating_workers
    end

    def before_start
    end

    def after_creating_workers
    end

    def after_complete
    end

    def after_job_finishes
    end
  end
end
