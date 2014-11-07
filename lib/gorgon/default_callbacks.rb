module Gorgon
  class DefaultCallbacks

    # @return job Id. Job Id is used to identify the job queue in Rabbit
    def before_job_starts
    end

    def after_job_finishes
    end
  end
end