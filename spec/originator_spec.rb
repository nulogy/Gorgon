require 'gorgon/originator'

describe Originator do
  let(:protocol){ stub("Originator Protocol", :connect => nil, :publish_files => nil,
                       :publish_job => nil, :receive_payloads => nil, :cancel_job => nil,
                       :disconnect => nil)}

  let(:configuration){ {:job => {}, :files => ["some/file"]}}
  let(:job_state){ stub("JobState", :is_job_complete? => false, :file_finished => nil,
                        :add_observer => nil)}
  let(:progress_bar_view){ stub("Progress Bar View", :show => nil)}
  let(:originator_logger){ stub("Originator Logger", :log => nil, :log_message => nil)}

  before do
    OriginatorLogger.stub(:new).and_return originator_logger
    @originator = Originator.new
  end

  describe "#publish_job" do
    before do
      stub_methods
    end

    it "creates a JobState instance and passes total files" do
      @originator.stub!(:files).and_return ["a file", "other file"]
      JobState.should_receive(:new).with(2).and_return job_state

      @originator.publish
    end

    it "creates a ProgressBarView and show" do
      JobState.stub!(:new).and_return job_state
      ProgressBarView.should_receive(:new).with(job_state).and_return progress_bar_view
      progress_bar_view.should_receive(:show)
      @originator.publish
    end
  end

  describe "#cancel_job" do
    before do
      stub_methods
    end

    it "call JobState#cancel" do
      JobState.stub!(:new).and_return job_state
      job_state.should_receive(:cancel)
      @originator.publish
      @originator.cancel_job
    end

    it "tells @protocol to cancel job and disconnect" do
      protocol.should_receive(:cancel_job)
      protocol.should_receive(:disconnect)
      @originator.publish
      @originator.cancel_job
    end
  end

  describe "#cleanup_if_job_complete" do
    before do
      stub_methods
      JobState.stub!(:new).and_return job_state
      @originator.publish
    end

    it "calls JobState#is_job_complete?" do
      job_state.should_receive(:is_job_complete?).and_return false
      @originator.cleanup_if_job_complete
    end

    it "disconnect if job is complete" do
      job_state.stub!(:is_job_complete?).and_return true
      protocol.should_receive(:disconnect)
      @originator.cleanup_if_job_complete
    end
  end

  describe "#handle_reply" do
    before do
      stub_methods
      JobState.stub!(:new).and_return job_state
      @originator.publish
    end

    it "calls cleanup_if_job_complete" do
      @originator.should_receive(:cleanup_if_job_complete)
      @originator.handle_reply finish_payload
    end

    it "calls JobState#file_started if payload[:action] is 'start'" do
      payload = Yajl::Parser.new(:symbolize_keys => true).parse(start_payload)
      job_state.should_receive(:file_started)
      @originator.handle_reply(start_payload)
    end

    it "calls JobState#file_finished if payload[:action] is 'finish'" do
      payload = Yajl::Parser.new(:symbolize_keys => true).parse(finish_payload)
      job_state.should_receive(:file_finished).with(payload)
      @originator.handle_reply(finish_payload)
    end

    let(:crash_message) {{:type => "crash", :hostname => "host",
        :stdout => "some output", :stderr => "some errors"}}

    it "calls JobState#crash if payload[:type] is 'crash'" do
      job_state.should_receive(:crash_message).with(crash_message)
      @originator.handle_reply(Yajl::Encoder.encode(crash_message))
    end
  end

  describe "#job_definition" do
    it "returns a JobDefinition object" do
      @originator.stub!(:configuration).and_return configuration
      job_definition = JobDefinition.new
      JobDefinition.should_receive(:new).and_return job_definition
      @originator.job_definition.should equal job_definition
    end

    it "builds source_tree_path if it was not specified in the configuration" do
      @originator.stub!(:configuration).and_return({:job => {}})
      @originator.job_definition.source_tree_path.should == "#{Etc.getlogin}@#{Socket.gethostname}:#{Dir.pwd}"
    end

    it "returns source_tree_path specified in configuration if it is present" do
      @originator.stub!(:configuration).and_return({:job => {:source_tree_path => "login@host:path/to/dir"}})
      @originator.job_definition.source_tree_path.should == "login@host:path/to/dir"
    end
  end

  private

  def stub_methods
    EventMachine.stub!(:run).and_yield
    ProgressBarView.stub!(:new).and_return progress_bar_view
    OriginatorProtocol.stub!(:new).and_return protocol
    @originator.stub!(:configuration).and_return configuration
    @originator.stub!(:connection_information).and_return 'host'
    @originator.stub!(:job_definition).and_return JobDefinition.new
  end

  def start_payload
    '{
      "action": "start",
      "hostname": "host",
      "worker_id": "1",
      "filename": "test/file_test.rb"
    }'
  end

  def finish_payload
    '{
      "action": "finish",
      "hostname": "host",
      "worker_id": "1",
      "filename": "test/file_test.rb",
      "failures": [],
      "type": "pass",
      "time": 3
    }'
  end
end
