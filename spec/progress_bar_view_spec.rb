require 'gorgon/progress_bar_view'
require 'gorgon/job_state'

describe Gorgon::ProgressBarView do
  before do
    allow(EventMachine::PeriodicTimer).to receive(:new)
  end

  describe "#initialize" do
    it "adds itself to observers of job_state" do
      job_state = Gorgon::JobState.new 1
      expect(job_state).to receive(:add_observer)
      Gorgon::ProgressBarView.new job_state
    end
  end

  describe "#show" do
    before do
      job_state = Gorgon::JobState.new 1
      @progress_bar_view = Gorgon::ProgressBarView.new job_state
    end

    it "prints in console gorgon's version and that is loading workers" do
      expect($stdout).to receive(:write).with(/loading .*workers/i)
      expect(ProgressBar).not_to receive(:create)
      @progress_bar_view.show
    end
  end

  describe "#update" do
    let(:progress_bar) { double("Progress Bar", :title= => nil, :progress= => nil, :format => nil,
                              :finished? => false)}
    let(:payload) {
      { :filename => "path/file.rb",
        :hostname => "host",
        :failures => ["Failure messages"]}
    }

    before do
      allow(ProgressBar).to receive(:create).and_return progress_bar
      @job_state = Gorgon::JobState.new 2
      allow(@job_state).to receive(:state).and_return :running
      @progress_bar_view = Gorgon::ProgressBarView.new @job_state
      allow($stdout).to receive(:write)
      @progress_bar_view.show
    end

    it "doesn't create ProgressBar if JobState is not running" do
      expect(@job_state).to receive(:state).and_return :starting
      expect(ProgressBar).not_to receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "doesn't create a ProgressBar if one was already created" do
      @progress_bar_view.update
      expect(ProgressBar).not_to receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "gets total files from JobState and create a ProgressBar once JobState is running" do
      expect(ProgressBar).to receive(:create).with(hash_including(:total => 2))
      @progress_bar_view.update
    end

    it "gets finished_files_count" do
      expect(@job_state).to receive :finished_files_count
      @progress_bar_view.update
    end

    it "gets failed_files_count" do
      expect(@job_state).to receive(:failed_files_count).and_return 0
      @progress_bar_view.update
    end

    it "prints failures and finish progress_bar when job is done" do
      @progress_bar_view.update
      allow(@job_state).to receive(:each_failed_test).and_yield(payload)
      allow(@job_state).to receive(:is_job_complete?).and_return :true
      expect($stdout).to   receive(:write).with(/Failure messages/)
      @progress_bar_view.update
    end

    context "when job is cancelled" do
      before do
        @progress_bar_view.update
        allow(@job_state).to receive(:is_job_cancelled?).and_return :true
      end

      it "prints failures and finish progress_bar when job is cancelled" do
        allow(@job_state).to receive(:each_failed_test).and_yield(payload)
        expect($stdout).to receive(:write).with(/Failure messages/)
        @progress_bar_view.update
      end

      it "prints files that were running when the job was cancelled" do
        expect(@job_state).to receive(:each_running_file).and_yield("hostname", "file1.rb")
        expect($stdout).to receive(:write).with(/file1\.rb.*hostname/)
        @progress_bar_view.update
      end
    end

    context "when payload is a crash message" do
      let(:crash_message) {{:type => "crash", :hostname => "host",
          :stdout => "some output", :stderr => "some errors"}}
      it "prints info about crash in standard error" do
        allow($stderr).to receive(:write)
        expect($stderr).to receive(:write).with(/crash.*host/i)
        expect($stderr).to receive(:write).with(/some output/i)
        expect($stderr).to receive(:write).with(/some errors/i)
        @progress_bar_view.update crash_message
      end
    end
  end
end
