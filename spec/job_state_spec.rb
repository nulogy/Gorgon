require 'gorgon/job_state'

describe Gorgon::JobState do
  let(:payload) {
    {:hostname => "host-name", :worker_id => "worker1", :filename => "path/file.rb",
      :type => "pass", :failures => []}
  }

  let (:host_state){ double("Host State", :file_started => nil, :file_finished => nil)}

  subject { Gorgon::JobState.new 5 }
  it { should respond_to :failed_files_count }
  it { should respond_to :finished_files_count }
  it { should respond_to(:file_started).with(1).argument }
  it { should respond_to(:file_finished).with(1).argument }
  it { should respond_to(:gorgon_crash_message).with(1).argument }
  it { should respond_to :cancel }
  it { should respond_to :each_failed_test }
  it { should respond_to :each_running_file }
  it { should respond_to :total_running_hosts }
  it { should respond_to :total_running_workers }
  it { should respond_to :is_job_complete? }
  it { should respond_to :is_job_cancelled? }

  before do
    @job_state = Gorgon::JobState.new 5
  end

  describe "#initialize" do
    it "sets total files for job" do
      expect(@job_state.total_files).to eq(5)
    end

    it "sets remaining_files_count" do
      expect(@job_state.remaining_files_count).to eq(5)
    end

    it "sets failed_files_count to 0" do
      expect(@job_state.failed_files_count).to eq(0)
    end

    it "set state to starting" do
      expect(@job_state.state).to eq(:starting)
    end
  end

  describe "#finished_files_count" do
    it "returns total_files - remaining_files_count" do
      expect(@job_state.finished_files_count).to eq(0)
    end
  end

  describe "#file_started" do
    it "change state to running after first start_file_message is received" do
      @job_state.file_started({})
      expect(@job_state.state).to eq(:running)
    end

    it "creates a new HostState object if this is the first file started by 'hostname'" do
      expect(Gorgon::HostState).to receive(:new).and_return host_state
      @job_state.file_started(payload)
    end

    it "doesn't create a new HostState object if this is not the first file started by 'hostname'" do
      allow(Gorgon::HostState).to receive(:new).and_return host_state
      @job_state.file_started(payload)
      expect(Gorgon::HostState).not_to receive(:new)
      @job_state.file_started(payload)
    end

    it "calls #file_started on HostState object representing 'hostname'" do
      allow(Gorgon::HostState).to receive(:new).and_return host_state
      expect(host_state).to receive(:file_started).with("worker_id", "file_name")
      @job_state.file_started({:hostname => "hostname",
                                :worker_id => "worker_id",
                                :filename => "file_name"})
    end

    it "notify observers" do
      expect(@job_state).to receive :notify_observers
      expect(@job_state).to receive :changed
      @job_state.file_started({})
    end
  end

  describe "#file_finished" do
    before do
      allow(Gorgon::HostState).to receive(:new).and_return host_state
      @job_state.file_started payload
    end

    it "decreases remaining_files_count" do
      expect(lambda do
        @job_state.file_finished payload
      end).to change{@job_state.remaining_files_count}.by(-1)

      expect(@job_state.total_files).to eq(5)
    end

    it "doesn't change failed_files_count if type test result is pass" do
      expect(lambda do
        @job_state.file_finished payload
      end).not_to change{@job_state.failed_files_count}
      expect(@job_state.failed_files_count).to eq(0)
    end

    it "increments failed_files_count if type is failed" do
      expect(lambda do
        @job_state.file_finished payload.merge({:type => "fail", :failures => ["Failure messages"]})
      end).to change{@job_state.failed_files_count}.by(1)
    end

    it "notify observers" do
      expect(@job_state).to receive :notify_observers
      expect(@job_state).to receive :changed
      @job_state.file_finished payload
    end

    it "raises if job already complete" do
      finish_job
      expect(lambda do
        @job_state.file_finished payload
      end).to raise_error(RuntimeError)
    end

    it "tells to the proper HostState object that a file finished in that host" do
      allow(Gorgon::HostState).to receive(:new).and_return host_state
      @job_state.file_started({:hostname => "hostname",
                                :worker_id => "worker_id",
                                :filename => "file_name"})
      expect(host_state).to receive(:file_finished).with("worker_id", "file_name")
      @job_state.file_finished({:hostname => "hostname",
                                 :worker_id => "worker_id",
                                 :filename => "file_name"})
    end
  end

  describe "#gorgon_crash_message" do
    let(:crash_msg) {{:type => "crash", :hostname => "host",
        :stdout => "some output", :stderr => "some errors"}}

    it "adds crashed host to JobState#crashed_hosted" do
      @job_state.gorgon_crash_message(crash_msg)
      expect(@job_state.crashed_hosts).to eq(["host"])
    end

    it "notify observers" do
      expect(@job_state).to receive :notify_observers
      expect(@job_state).to receive :changed
      @job_state.gorgon_crash_message crash_msg
    end
  end

  describe "#is_job_complete?" do
    it "returns false if remaining_files_count != 0" do
      expect(@job_state.is_job_complete?).to be_falsey
    end

    it "returns true if remaining_files_count == 0" do
      finish_job
      expect(@job_state.is_job_complete?).to be_truthy
    end
  end

  describe "#cancel and is_job_cancelled?" do
    it "cancels job" do
      expect(@job_state.is_job_cancelled?).to be_falsey
      @job_state.cancel
      expect(@job_state.is_job_cancelled?).to be_truthy
    end

    it "notify observers when cancelling" do
      expect(@job_state).to receive :changed
      expect(@job_state).to receive :notify_observers
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
        expect(test[:failures]).to eq(["Failure messages"])
      end
    end
  end

  describe "#each_running_file" do
    before do
      @job_state.file_started payload
      @job_state.file_started payload.merge({ :hostname => "host2",
                                              :filename => "path/file2.rb",
                                              :worker_id => "worker2"})
    end

    it "returns each running file" do
      hosts_files = {}
      @job_state.each_running_file do |hostname, filename|
        hosts_files[hostname] = filename
      end
     expect(hosts_files.size).to eq(2)
     expect(hosts_files["host-name"]).to eq("path/file.rb")
     expect(hosts_files["host2"]).to eq("path/file2.rb")
    end
  end

  describe "#total_running_hosts" do
    it "returns total number of hosts that has workers running files" do
      @job_state.file_started payload
      @job_state.file_started payload.merge({:worker_id => "worker2"})
      @job_state.file_started payload.merge({ :hostname => "host2",
                                              :filename => "path/file2.rb",
                                              :worker_id => "worker1"})
      expect(@job_state.total_running_hosts).to eq(2)
    end
  end

  describe "#total_running_workers" do
    it "returns total number of workers running accross all hosts" do
      @job_state.file_started payload
      @job_state.file_started payload.merge({:worker_id => "worker2"})
      @job_state.file_started payload.merge({ :hostname => "host2",
                                              :filename => "path/file2.rb",
                                              :worker_id => "worker1"})
      expect(@job_state.total_running_workers).to eq(3)
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
