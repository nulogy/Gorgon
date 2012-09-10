require 'gorgon/originator'

describe Originator do
  let(:connection) { stub("Connection", :disconnect => nil, :on_closed => nil)}
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil, :name => "queue", :purge => nil,
                     :delete => nil) }
  let(:exchange) { stub("Exchange", :publish => nil) }
  let(:channel) { stub("Channel", :queue => queue, :direct => exchange, :fanout => exchange,
                       :default_exchange => exchange) }

  let(:configuration){ {:files => ["some/file"]}}
  let(:job_state){ stub("JobState")}

  before do
    @originator = Originator.new
  end

  describe "#publish_job" do
    before do
      stub_connection_methods
    end

    it "creates a JobState instance and passes total files" do
      @originator.stub!(:files).and_return ["a file", "other file"]
      JobState.should_receive(:new).with(2).and_return job_state

      @originator.publish
    end
  end

  describe "#cancel_job" do
    before do
      stub_connection_methods
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
      stub_connection_methods
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

  private

  def stub_connection_methods
    AMQP.stub(:connect).and_return(connection)
    AMQP::Channel.stub!(:new).and_return channel
    EventMachine.stub!(:run).and_yield
    @originator.stub!(:configuration).and_return configuration
    @originator.stub!(:connection_information).and_return 'host'
    @originator.stub!(:job_definition).and_return JobDefinition.new
    @originator.stub!(:handle_reply).with({}).and_return nil
  end
end
