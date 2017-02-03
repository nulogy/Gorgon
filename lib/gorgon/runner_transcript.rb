class RunnerTranscript
  DEFAULT_OUTPUT_FILE = "/tmp/gorgon-runner-transcript.json"

  attr_accessor :workers

  def initialize(configuration, job_state)
    @job_state = job_state
    @output_file = configuration.fetch(:failed_files) { DEFAULT_OUTPUT_FILE }
    @workers = {}

    @job_state.add_observer(self)
  end

  def update(payload)
    if payload[:action] == "finish"
      @workers[payload[:worker_id]] ||= []
      @workers[payload[:worker_id]].push(payload[:filename])
    end

    if @job_state.is_job_complete? || @job_state.is_job_cancelled?
      File.open(@output_file, 'w+') do |fd|
        fd.write(Yajl::Encoder.encode(@workers))
      end
    end
  end
end
