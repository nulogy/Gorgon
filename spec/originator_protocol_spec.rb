require 'gorgon/originator_protocol'

describe Gorgon::OriginatorProtocol do
  let(:connection) { double("Connection", :disconnect => nil, :on_closed => nil)}
  let(:queue) { double("Queue", :bind => nil, :subscribe => nil, :name => "queue", :purge => nil,
                     :delete => nil) }
  let(:exchange) { double("Exchange", :publish => nil, :name => "exchange", :delete => nil) }
  let(:channel) { double("Channel", :queue => queue, :direct => exchange, :fanout => exchange,
                       :default_exchange => exchange) }
  let(:logger){ double("Logger", :log => nil)}

  before do
    AMQP.stub(:connect).and_return connection
    AMQP::Channel.stub(:new).and_return channel
    @originator_p = Gorgon::OriginatorProtocol.new logger
    @conn_information = {:host => "host"}
  end

  describe "#connect" do
    it "opens AMQP connection" do
      AMQP.should_receive(:connect).with(@conn_information)
      @originator_p.connect(@conn_information)
    end

    it "opens a new channel" do
      AMQP::Channel.should_receive(:new).with(connection)
      @originator_p.connect @conn_information
    end

    it "sets Connection#on_close callbacks" do
      on_disconnect_called = false
      on_disconnect = Proc.new { on_disconnect_called = true }
      connection.should_receive(:on_closed).and_yield

      @originator_p.connect @conn_information, :on_closed => on_disconnect
      @originator_p.disconnect
      on_disconnect_called.should be_true
    end

    it "opens a reply and exchange queue" do
      UUIDTools::UUID.stub(:timestamp_create).and_return 1
      channel.should_receive(:queue).once.with("reply_queue_1", :auto_delete => true)
      @originator_p.connect @conn_information
    end

    it "opens a reply exchange and binds reply queue to it" do
      UUIDTools::UUID.stub(:timestamp_create).and_return 1
      channel.should_receive(:direct).with("reply_exchange_1", :auto_delete => true)
      queue.should_receive(:bind).with(exchange)
      @originator_p.connect @conn_information
    end
  end

  describe "#publish_files" do
    before do
      @originator_p.connect @conn_information
    end

    it "publish each file using channel's default_exchange" do
      files = ["file1", "file2"]
      channel.should_receive(:default_exchange)
      exchange.should_receive(:publish).once.ordered.with("file1", :routing_key => "queue")
      exchange.should_receive(:publish).once.ordered.with("file2", :routing_key => "queue")
      @originator_p.publish_files files
    end
  end

  describe "#publish_job_to_all" do
    before do
      connect_and_publish_files(@originator_p)
    end

    it "adds queue's names to job_definition and fanout using 'gorgon.jobs' exchange" do
      channel.should_receive(:fanout).with("gorgon.jobs")
      expected_job_definition = Gorgon::JobDefinition.new
      expected_job_definition.file_queue_name = "queue"
      expected_job_definition.reply_exchange_name = "exchange"

      exchange.should_receive(:publish).with(expected_job_definition.to_json)
      @originator_p.publish_job_to_all Gorgon::JobDefinition.new
    end

    it "uses cluster_id in job_queue_name, when it is specified" do
      originator_p = connect_and_publish_files(Gorgon::OriginatorProtocol.new(logger, "cluster1"))

      channel.should_receive(:fanout).with("gorgon.jobs.cluster1")

      originator_p.publish_job_to_all Gorgon::JobDefinition.new
    end
  end

  describe "#publish_job_to_one" do
    before do
      connect_and_publish_files(@originator_p)
    end

    it "publishes the job to the specified listener queue" do
      expected_listener_queue_name = "abcd1234"
      expected_job_definition = Gorgon::JobDefinition.new
      expected_job_definition.file_queue_name = "queue"
      expected_job_definition.reply_exchange_name = "exchange"

      exchange.should_receive(:publish).with(expected_job_definition.to_json, {:routing_key => expected_listener_queue_name})

      @originator_p.publish_job_to_one(Gorgon::JobDefinition.new, expected_listener_queue_name)
    end
  end

  describe "#send_message_to_listeners" do
    before do
      @originator_p.connect @conn_information
    end

    it "adds type and reply_exchange_name to message and fanouts it using 'gorgon.jobs' exchange" do
      expected_msg = {:type => :msg_type, :reply_exchange_name => "exchange",
        :body => {:data => 'data'}}
      Yajl::Encoder.should_receive(:encode).with(expected_msg).and_return :msg
      channel.should_receive(:fanout).once.ordered.with("gorgon.jobs")
      exchange.should_receive(:publish).once.ordered.with(:msg)
      @originator_p.send_message_to_listeners :msg_type, :data => 'data'
    end
  end

  describe "#receive_payloads" do
    before do
      @originator_p.connect @conn_information
    end

    it "subscribe to reply_queue and yield payload" do
      payload = {:key => "info"}
      queue.should_receive(:subscribe).and_yield(payload)
      yielded = false
      @originator_p.receive_payloads do |p|
        yielded = true
        p.should == payload
      end
      yielded.should be_true
    end
  end

  describe "#cancel_job" do
    before do
      @originator_p.connect @conn_information
    end

    it "purges file_queue" do
      @originator_p.publish_files ['file1']
      queue.should_receive(:purge)
      @originator_p.cancel_job
    end

    it "fanout 'cancel' message using 'gorgon.worker_managers' exchange" do
      msg = Yajl::Encoder.encode({:action => "cancel_job"})
      channel.should_receive(:fanout).with("gorgon.worker_managers")
      exchange.should_receive(:publish).with(msg)
      @originator_p.cancel_job
    end
  end

  describe "#disconnect" do
    before do
      @originator_p.connect @conn_information
    end

    it "deletes reply_exchange and reply and file queues" do
      @originator_p.publish_files []
      queue.should_receive(:delete).exactly(3).times
      exchange.should_receive(:delete)
      @originator_p.disconnect
    end

    it "disconnects connection" do
      connection.should_receive(:disconnect)
      @originator_p.disconnect
    end
  end

  def connect_and_publish_files(originator_p)
    originator_p.connect @conn_information
    originator_p.publish_files []
    originator_p
  end
end
