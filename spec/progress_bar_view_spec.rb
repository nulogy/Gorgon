require 'gorgon/progress_bar_view'
require 'gorgon/job_state'

describe ProgressBarView do
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

    it "gets total files from JobState and create a ProgressBar" do
      ProgressBar.should_receive(:create).with(hash_including(:total => 1))
      @progress_bar_view.show
    end
  end

  # describe "#update" do
  #   let(:progress_bar) { stub("Progress Bar", :title= => nil, :progress= => nil, :format => nil)}

  #   before do
  #     ProgressBar.stub!(:create).and_return progress_bar
  #     job_state = JobState.new 2
  #     @progress_bar_view = ProgressBarView.new job_state
  #     @progress_bar_view.show
  #   end

  #   it "set title" do
  #   end
  # end
end
