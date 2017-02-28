module Gorgon
  class Job
    def initialize(listener, job_definition)
      @workers = []
      @definition = job_definition
    end



    def add_worker

    end

    def on_worker_complete
      @available_worker_slots += 1
      on_current_job_complete if current_job_complete?
    end

    def setup_child_process
      worker = ChildProcess.build("gorgon", "work", @worker_communication.name, @config_filename)

      worker_output = Tempfile.new("gorgon-worker")
      worker.io.stdout = worker_output
      worker.io.stderr = worker_output
      worker
    end
  end
end
