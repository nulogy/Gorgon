require 'gorgon/job_state'

describe JobState do
  let(:payload) {
    {:hostname => "host-name", :worker_id => "worker1", :filename => "path/file.rb",
      :type => "pass", :failures => []}
  }

  let (:host_state){ stub("Host State", :file_started => nil, :file_finished => nil)}

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

    it "set state to starting" do
      @job_state.state.should be :starting
    end
  end

  describe "#finished_files_count" do
    it "returns total_files - remaining_files_count" do
      @job_state.finished_files_count.should be 0
    end
  end

  describe "#file_started" do
    it "change state to running after first start_file_message is received" do
      @job_state.file_started({})
      @job_state.state.should be :running
    end

    it "creates a new HostState object if this is the first file started by 'hostname'" do
      HostState.should_receive(:new).and_return host_state
      @job_state.file_started(payload)
    end

    it "doesn't create a new HostState object if this is not the first file started by 'hostname'" do
      HostState.stub!(:new).and_return host_state
      @job_state.file_started(payload)
      HostState.should_not_receive(:new)
      @job_state.file_started(payload)
    end

    it "calls #file_started on HostState object representing 'hostname'" do
      HostState.stub!(:new).and_return host_state
      host_state.should_receive(:file_started).with("worker_id", "file_name")
      @job_state.file_started({:hostname => "hostname",
                                :worker_id => "worker_id",
                                :filename => "file_name"})
    end

    it "notify observers" do
      @job_state.should_receive :notify_observers
      @job_state.should_receive :changed
      @job_state.file_started({})
    end
  end

  describe "#file_finished" do
    before do
      HostState.stub!(:new).and_return host_state
      @job_state.file_started payload
    end

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
        @job_state.file_finished payload.merge({:type => "fail", :failures => ["Failure messages"]})
      end.should change(@job_state, :failed_files_count).by(1)
    end

    it "notify observers" do
      @job_state.should_receive :notify_observers
      @job_state.should_receive :changed
      @job_state.file_finished payload
    end

    it "raises if job already complete" do
      finish_job
      lambda do
        @job_state.file_finished payload
      end.should raise_error
    end

    it "raises if job was cancelled" do
      @job_state.cancel
      lambda do
        @job_state.file_finished payload
      end.should raise_error
    end

    it "tells to the proper HostState object that a file finished in that host" do
      HostState.stub!(:new).and_return host_state
      @job_state.file_started({:hostname => "hostname",
                                :worker_id => "worker_id",
                                :filename => "file_name"})
      host_state.should_receive(:file_finished).with("worker_id", "file_name")
      @job_state.file_finished({:hostname => "hostname",
                                 :worker_id => "worker_id",
                                 :filename => "file_name"})
    end
  end

  describe "#is_job_complete?" do
    it "returns false if remaining_files_count != 0" do
      @job_state.is_job_complete?.should be_false
    end

    it "returns true if remaining_files_count == 0" do
      finish_job
      @job_state.is_job_complete?.should be_true
    end
  end

  describe "#cancel and is_job_cancelled?" do
    it "cancels job" do
      @job_state.is_job_cancelled?.should be_false
      @job_state.cancel
      @job_state.is_job_cancelled?.should be_true
    end

    it "notify observers when cancelling" do
      @job_state.should_receive :changed
      @job_state.should_receive :notify_observers
      @job_state.cancel
    end
  end

  describe "#each_failed_test" do
    before do
      @job_state.file_started payload
    end

    it "returns failed tests info" do
      @job_state.file_finished payload.merge({:type => "fail", :failures => ["Failure messages"]})
      @job_state.each_failed_test do |test|
        test[:failures].should == ["Failure messages"]
      end
    end
  end

  private

  def finish_job
    5.times do
      @job_state.file_started payload
      @job_state.file_finished payload
    end
  end
end
