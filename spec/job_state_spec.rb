require 'gorgon/job_state'

describe JobState do
  before do
    @job_state = JobState.new 5
  end

  describe "#initialize" do
    it "sets total files for job" do
      @job_state.total_files.should be 5
    end

    it "sets remaining_files_count" do
      @job_state.remaining_files_count.should be 5
    end

    it "sets failed_files_count to 0" do
      @job_state.failed_files_count.should be 0
    end
  end

  describe "#finished_files_count" do
    it "returns total_files - remaining_files_count" do
      @job_state.finished_files_count.should be 0
    end
  end

  describe "#file_finished" do
    let(:payload) {
      {:hostname => "host-name", :worker_id => 1, :filename => "path/file.rb",
      :type => "pass", :failures => []}
    }

    it "decreases remaining_files_count" do
      lambda do
        @job_state.file_finished payload
      end.should(change(@job_state, :remaining_files_count).by(-1))

      @job_state.total_files.should be 5
    end

    it "doesn't change failed_files_count if type test result is pass" do
      lambda do
        @job_state.file_finished payload
      end.should_not change(@job_state, :failed_files_count)
      @job_state.failed_files_count.should be 0
    end

    it "increments failed_files_count if type is failed" do
      lambda do
        @job_state.file_finished payload.merge({:type => "fail", :failures => ["Failures message"]})
      end.should change(@job_state, :failed_files_count).by(1)
    end

    it "notify observers" do
      @job_state.should_receive :notify_observers
      @job_state.file_finished payload
    end
  end

  describe "#file_started"
end
