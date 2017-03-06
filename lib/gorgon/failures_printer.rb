require 'yajl'

module Gorgon
  class FailuresPrinter
    DEFAULT_OUTPUT_FILE = "/tmp/gorgon-failed-files.json"

    attr_reader :output_file

    def initialize(configuration, job_state)
      @job_state = job_state
      @job_state.add_observer(self)
      @output_file = configuration.fetch(:failed_files) { DEFAULT_OUTPUT_FILE }
    end

    def update payload
      return unless @job_state.is_job_complete? || @job_state.is_job_cancelled?

      File.open(@output_file, 'w+') do |fd|
        fd.write(Yajl::Encoder.encode(failed_files + unfinished_files))
      end
    end

    private

    def failed_files
      failed_files = []
      @job_state.each_failed_test do |test|
        failed_files << "#{test[:filename]}"
      end
      failed_files
    end

    def unfinished_files
      unfinished_files = []
      @job_state.each_running_file do |hostname, filename|
        unfinished_files << "#{filename}"
      end
      unfinished_files
    end
  end
end
