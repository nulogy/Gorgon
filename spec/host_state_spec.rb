require 'gorgon/host_state'

describe Gorgon::HostState do
  it { should respond_to(:file_started).with(2).arguments }
  it { should respond_to(:file_finished).with(2).arguments }
  it { should respond_to(:each_running_file).with(0).argument }
  it { should respond_to(:total_running_workers).with(0).argument }

  before do
    @host_state = Gorgon::HostState.new
  end

  describe "#total_workers_running" do
    it "returns 0 if there are no worker running files" do
      @host_state.total_running_workers.should == 0
    end

    it "returns 1 if #file_started was called, but #file_finished has not been called with such a worker id" do
      @host_state.file_started "worker1", "path/to/file.rb"
      @host_state.total_running_workers.should == 1
    end

    it "returns 0 if #file_started and #file_finished were called for the same worker_id" do
      @host_state.file_started "worker1", "path/to/file.rb"
      @host_state.file_finished "worker1", "path/to/file.rb"
      @host_state.total_running_workers.should == 0
    end

    it "returns 1 if #file_started and #file_finished were called for different worker id (worker1)" do
      @host_state.file_started "worker1", "path/to/file.rb"
      @host_state.file_started "worker2", "path/to/file2.rb"
      @host_state.file_finished "worker2", "path/to/file2.rb"
      @host_state.total_running_workers.should == 1
    end
  end

  describe "#each_running_file" do
    before do
      @host_state.file_started "worker1", "path/to/file1.rb"
      @host_state.file_started "worker2", "path/to/file2.rb"
    end

    context "when no #file_finished has been called" do
      it "yields each currently running file" do
        files = []
        @host_state.each_running_file do |file|
          files << file
        end
        files.should == ["path/to/file1.rb", "path/to/file2.rb"]
      end
    end

    context "when #file_finished has been called for one of the workers" do
      it "yields each currently running file" do
        @host_state.file_finished "worker2", "path/to/file2.rb"

        files = []
        @host_state.each_running_file do |file|
          files << file
        end
        files.should == ["path/to/file1.rb"]
      end
    end
  end
end
