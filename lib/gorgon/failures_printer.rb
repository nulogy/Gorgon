require 'yajl'

class FailuresPrinter
  OUTPUT_FILE = "/tmp/gorgon-failed-files.json"

  def initialize job_state
    @job_state = job_state
    @job_state.add_observer(self)
  end

  def update payload
    return unless @job_state.is_job_complete? || @job_state.is_job_cancelled?

    failed_files = []
    @job_state.each_failed_test do |test|
      failed_files << "#{test[:filename]}"
    end

    File.open(OUTPUT_FILE, 'w+') do |f|
      f.write(Yajl::Encoder.encode(failed_files))
    end
  end
end

