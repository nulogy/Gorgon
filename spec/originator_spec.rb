require 'gorgon/originator'

describe Originator do
  let(:connection) { stub("Connection", :disconnect => nil, :on_closed => nil)}
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil, :name => "queue", :purge => nil,
                     :delete => nil) }
  let(:exchange) { stub("Exchange", :publish => nil) }
  let(:channel) { stub("Channel", :queue => queue, :direct => exchange, :fanout => exchange,
                       :default_exchange => exchange) }

  let(:configuration){ {:files => ["some/file"]}}
  let(:job_state){ stub("JobState", :is_job_complete? => false, :file_finished => nil)}
  let(:progress_bar_view){ stub("Progress Bar View", :show => nil)}

  before do
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

    it "cleans queues and disconect" do
      queue.should_receive(:delete).twice #one for reply_queue and other for file_queue
      connection.should_receive(:disconnect)
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

    it "cleans queues and disconect if job is complete" do
      job_state.stub!(:is_job_complete?).and_return true
      queue.should_receive(:delete).twice #one for reply_queue and other for file_queue
      connection.should_receive(:disconnect)
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
  end

  private

  def stub_methods
    AMQP.stub(:connect).and_return(connection)
    AMQP::Channel.stub!(:new).and_return channel
    EventMachine.stub!(:run).and_yield
    ProgressBarView.stub!(:new).and_return progress_bar_view
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
