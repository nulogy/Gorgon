require 'yajl'

module Gorgon
  class RuntimeRecorder
    attr_accessor :records

    def initialize(job_state, runtime_filename)
      @records = {}
      @job_state = job_state
      @job_state.add_observer(self)
      @runtime_filename = runtime_filename || ""
    end

    def update payload
      @records[payload[:filename]] = payload[:runtime] if payload[:action] == "finish"
      self.write_records_to_file if @job_state.is_job_complete?
    end

    def write_records_to_file
      return if @runtime_filename.empty?
      make_directories
      @records = Hash[@records.sort_by{|filename, runtime| -1*runtime}]
      File.open(@runtime_filename, 'w') do |f|
        f.write(Yajl::Encoder.encode(@records, pretty: true))
      end
    end


    private

    def make_directories
      dirname = File.dirname(@runtime_filename)
      FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
    end

  end
end
