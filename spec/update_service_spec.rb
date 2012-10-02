require 'gorgon/update_service'

describe UpdateService do
  let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
  let(:protocol) { stub("OriginatorProtocol", :connect => nil,
                        :receive_payloads => nil, :disconnect => nil,
                        :send_update_message => nil)}
  let(:logger){ stub("Originator Logger", :log => nil, :log_message => nil)}

  before do
    $stdout.stub!(:write)
    UpdateService.any_instance.stub(:load_configuration_from_file).and_return configuration
    EM.stub!(:run).and_yield
    EM.stub!(:add_periodic_timer).and_yield
    OriginatorLogger.stub!(:new).and_return logger
    OriginatorProtocol.stub!(:new).and_return(protocol)
    @service = UpdateService.new
  end

  describe "#update" do
    it "runs EventMachine loop and connect using configuration[:connection]" do
      EM.should_receive(:run)
      protocol.should_receive(:connect).once.ordered.with({:host => "host"}, anything)
      @service.update
    end

    it "calls Protocol#send_update_message with version number" do
      protocol.should_receive(:send_update_message).with("1.2.0")
      @service.update "1.2.0"
    end

    it "adds a periodic timer that checks if there is any listener updating" do
      EM.should_receive(:add_periodic_timer).with(UpdateService::TIMEOUT)
      @service.update
    end

    context "when it receives an updating message" do
      before do
        payload = {:type => "updating", :hostname => "host"}
        protocol.stub!(:receive_payloads).and_yield Yajl::Encoder.encode(payload)
      end

      it "writes to console" do
        $stdout.should_receive(:write).with(/host/)
        @service.update
      end

      it "won't diconnect as long as there is a host updating" do
        protocol.should_not_receive(:disconnect)
        @service.update
      end
    end

    context "when it receives an update_complete message" do
      before do
        updating_payload = {:type => "updating", :hostname => "host"}
        complete_payload = {:type => "update_complete", :hostname => "host", :new_version => "1.2.3"}
        protocol.stub!(:receive_payloads).and_yield(Yajl::Encoder.encode(updating_payload))
          .and_yield(Yajl::Encoder.encode(complete_payload))
      end

      it "writes to console" do
        $stdout.should_receive(:write).twice.with(/host/)
        @service.update
      end

      it "disconnect since there is no host updating anymore" do
        protocol.should_receive(:disconnect)
        @service.update
      end
    end
  end
end
