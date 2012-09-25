require 'gorgon/ping_service'

describe "PingService" do
  describe "#ping_listeners" do
    let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
    let(:protocol) { stub("OriginatorProtocol", :connect => nil, :ping => nil,
                          :receive_payloads => nil, :disconnect => nil)}
    let(:logger){ stub("Originator Logger", :log => nil, :log_message => nil)}

    before do
      PingService.any_instance.stub(:load_configuration_from_file).and_return configuration
      OriginatorLogger.stub!(:new).and_return logger
    end

    it "connnects and calls OriginatorProtocol#ping" do
      OriginatorProtocol.should_receive(:new).once.ordered.and_return(protocol)
      protocol.should_receive(:connect).once.ordered.with({:host => "host"})
      protocol.should_receive(:ping).once.ordered
      PingService.new.ping_listeners
    end

  end
end
