require 'gorgon/originator_protocol'

describe OriginatorProtocol do
  let(:connection) { stub("Connection", :disconnect => nil, :on_closed => nil)}
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil, :name => "queue", :purge => nil,
                     :delete => nil) }
  let(:exchange) { stub("Exchange", :publish => nil) }
  let(:channel) { stub("Channel", :queue => queue, :direct => exchange, :fanout => exchange,
                       :default_exchange => exchange) }

  before do
    AMQP.stub!(:connect).and_return connection
    AMQP::Channel.stub!(:new).and_return channel
    @originator_p = OriginatorProtocol.new
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
      on_disconnect = Proc.new {}
      connection.should_receive(:on_closed).and_yield
      @originator_p.connect @conn_information, :on_closed => on_disconnect
    end
  end
end
