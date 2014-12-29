require 'yajl'

class RuntimeRecorder
  attr_accessor :records

  def initialize(job_state, runtime_filename)
    @records = {}
    @job_state = job_state
    @job_state.add_observer(self)
    @runtime_filename = runtime_filename || ""
  end

  def update payload
    if payload[:action] == "finish"
      type = @job_state.failed_test?(payload) ? :failed : :passed
      @records[payload[:filename]] = [type, payload[:runtime]]
    end
    self.write_records_to_file if @job_state.is_job_complete?
  end

  def write_records_to_file
    return if @runtime_filename.empty?
    make_directories
    sort_records
    File.open(@runtime_filename, 'w') do |f|
      f.write(Yajl::Encoder.encode(@records, pretty: true))
    end
  end


  private

  def sort_records
    @records = Hash[@records.sort_by{|filename, value| [
      (value[0] == :failed) ? 0 : 1,   # prioritize failed tests
      -1*value[1],   # prioritize tests with longer runtime
    ]}]
  end

  def make_directories
    dirname = File.dirname(@runtime_filename)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  end

end

