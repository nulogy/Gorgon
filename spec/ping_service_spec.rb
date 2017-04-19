require 'gorgon/ping_service'

describe Gorgon::PingService do
  describe "#ping_listeners" do
    let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
    let(:protocol) { double("OriginatorProtocol", :connect => nil, :ping => nil,
                          :receive_payloads => nil, :disconnect => nil,
                          :send_message_to_listeners => nil)}
    let(:logger){ double("Originator Logger", :log => nil, :log_message => nil)}

    before do
      allow($stdout).to receive(:write)
      allow_any_instance_of(Gorgon::PingService).to receive(:load_configuration_from_file).and_return configuration
      allow(EventMachine).to receive(:run).and_yield
      allow(EM).to receive(:add_timer).and_yield
      allow(Gorgon::OriginatorLogger).to receive(:new).and_return logger
    end

    it "connnects and calls OriginatorProtocol#send_message_to_listeners" do
      expect(Gorgon::OriginatorProtocol).to receive(:new).once.ordered.and_return(protocol)
      expect(protocol).to receive(:connect).once.ordered.with({:host => "host"}, anything)
      expect(protocol).to receive(:send_message_to_listeners).once.ordered
      Gorgon::PingService.new.ping_listeners
    end

    context "after sending ping messages" do
      before do
        allow(Gorgon::OriginatorProtocol).to receive(:new).and_return(protocol)
        @service = Gorgon::PingService.new
      end

      it "adds an Event machine timer" do
        expect(EM).to receive(:add_timer).and_yield
        @service.ping_listeners
      end

      it "receives a ping_response message" do
        payload = {:type => "ping_response", :hostname => "host", :version => "1.1.1"}
        expect(protocol).to receive(:receive_payloads).and_yield Yajl::Encoder.encode(payload)
        @service.ping_listeners
      end
    end
  end
end
