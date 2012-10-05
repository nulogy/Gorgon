require 'gorgon/progress_bar_view'
require 'gorgon/job_state'

describe ProgressBarView do
  before do
    EventMachine::PeriodicTimer.stub(:new)
  end

  describe "#initialize" do
    it "adds itself to observers of job_state" do
      job_state = JobState.new 1
      job_state.should_receive(:add_observer)
      ProgressBarView.new job_state
    end
  end

  describe "#show" do
    before do
      job_state = JobState.new 1
      @progress_bar_view = ProgressBarView.new job_state
    end

    it "prints in console gorgon's version and that is loading workers" do
      $stdout.should_receive(:write).with(/loading .*workers/i)
      ProgressBar.should_not_receive(:create)
      @progress_bar_view.show
    end
  end

  describe "#update" do
    let(:progress_bar) { stub("Progress Bar", :title= => nil, :progress= => nil, :format => nil,
                              :finished? => false)}
    let(:payload) {
      { :filename => "path/file.rb",
        :hostname => "host",
        :failures => ["Failure messages"]}
    }

    before do
      ProgressBar.stub!(:create).and_return progress_bar
      @job_state = JobState.new 2
      @job_state.stub!(:state).and_return :running
      @progress_bar_view = ProgressBarView.new @job_state
      $stdout.stub!(:write)
      @progress_bar_view.show
    end

    it "doesn't create ProgressBar if JobState is not running" do
      @job_state.should_receive(:state).and_return :starting
      ProgressBar.should_not_receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "doesn't create a ProgressBar if one was already created" do
      @progress_bar_view.update
      ProgressBar.should_not_receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "gets total files from JobState and create a ProgressBar once JobState is running" do
      ProgressBar.should_receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "gets finished_files_count" do
      @job_state.should_receive :finished_files_count
      @progress_bar_view.update
    end

    it "gets failed_files_count" do
      @job_state.should_receive(:failed_files_count).and_return 0
      @progress_bar_view.update
    end

    it "prints failures and finish progress_bar when job is done" do
      @progress_bar_view.update
      @job_state.stub!(:each_failed_test).and_yield(payload)
      @job_state.stub!(:is_job_complete?).and_return :true
      $stdout.should_receive(:write).with(/Failure messages/)
      @progress_bar_view.update
    end

    context "when job is cancelled" do
      before do
        @progress_bar_view.update
        @job_state.stub!(:is_job_cancelled?).and_return :true
      end

      it "prints failures and finish progress_bar when job is cancelled" do
        @job_state.stub!(:each_failed_test).and_yield(payload)
        $stdout.should_receive(:write).with(/Failure messages/)
        @progress_bar_view.update
      end

      it "prints files that were running when the job was cancelled" do
        @job_state.should_receive(:each_running_file).and_yield("hostname", "file1.rb")
        $stdout.should_receive(:write).with(/file1\.rb.*hostname/)
        @progress_bar_view.update
      end
    end

    context "when payload is a crash message" do
      let(:crash_message) {{:type => "crash", :hostname => "host",
          :stdout => "some output", :stderr => "some errors"}}
      it "prints info about crash in standard error" do
        $stderr.stub!(:write)
        $stderr.should_receive(:write).with(/crash.*host/i)
        $stderr.should_receive(:write).with(/some output/i)
        $stderr.should_receive(:write).with(/some errors/i)
        @progress_bar_view.update crash_message
      end
    end
  end
end
