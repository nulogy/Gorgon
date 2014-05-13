require 'gorgon/ping_service'

describe "PingService" do
  describe "#ping_listeners" do
    let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
    let(:protocol) { double("OriginatorProtocol", :connect => nil, :ping => nil,
                          :receive_payloads => nil, :disconnect => nil,
                          :send_message_to_listeners => nil)}
    let(:logger){ double("Originator Logger", :log => nil, :log_message => nil)}

    before do
      $stdout.stub(:write)
      PingService.any_instance.stub(:load_configuration_from_file).and_return configuration
      EventMachine.stub(:run).and_yield
      EM.stub(:add_timer).and_yield
      OriginatorLogger.stub(:new).and_return logger
    end

    it "connnects and calls OriginatorProtocol#send_message_to_listeners" do
      OriginatorProtocol.should_receive(:new).once.ordered.and_return(protocol)
      protocol.should_receive(:connect).once.ordered.with({:host => "host"}, anything)
      protocol.should_receive(:send_message_to_listeners).once.ordered
      PingService.new.ping_listeners
    end

    context "after sending ping messages" do
      before do
        OriginatorProtocol.stub(:new).and_return(protocol)
        @service = PingService.new
      end

      it "adds an Event machine timer" do
        EM.should_receive(:add_timer).and_yield
        @service.ping_listeners
      end

      it "receives a ping_response message" do
        payload = {:type => "ping_response", :hostname => "host", :version => "1.1.1"}
        protocol.should_receive(:receive_payloads).and_yield Yajl::Encoder.encode(payload)
        @service.ping_listeners
      end
    end
  end
end
