require 'gorgon/gem_service'

describe Gorgon::GemService do
  let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
  let(:protocol) { double("OriginatorProtocol", :connect => nil,
                        :receive_payloads => nil, :disconnect => nil,
                        :send_message_to_listeners => nil)}
  let(:logger){ double("Originator Logger", :log => nil, :log_message => nil)}

  before do
    allow($stdout).to receive(:write)
    allow_any_instance_of(Gorgon::GemService).to receive(:load_configuration_from_file).and_return configuration
    allow(EM).to receive(:run).and_yield
    allow(EM).to receive(:add_periodic_timer).and_yield
    allow(Gorgon::OriginatorLogger).to receive(:new).and_return logger
    allow(Gorgon::OriginatorProtocol).to receive(:new).and_return(protocol)
    @service = Gorgon::GemService.new
    @command = "install"
  end

  describe "#run" do
    it "runs EventMachine loop and connect using configuration[:connection]" do
      expect(EM).to receive(:run)
      expect(protocol).to receive(:connect).once.ordered.with({:host => "host"}, anything)
      @service.run @command
    end

    it "calls Protocol#send_message_to_listeners with version number" do
      expect(protocol).to receive(:send_message_to_listeners).with(:gem_command, :gem_command => @command)
      @service.run @command
    end

    it "adds a periodic timer that checks if there is any listener running command" do
      expect(EM).to receive(:add_periodic_timer).with(Gorgon::GemService::TIMEOUT)
      @service.run @command
    end

    context "when it receives an running_command message" do
      before do
        payload = {:type => "running_command", :hostname => "host"}
        allow(protocol).to receive(:receive_payloads).and_yield Yajl::Encoder.encode(payload)
      end

      it "writes to console" do
        expect($stdout).to receive(:write).with(/host/)
        @service.run @command
      end

      it "won't diconnect as long as there is a host running_command" do
        expect(protocol).not_to receive(:disconnect)
        @service.run @command
      end
    end

    context "when it receives an command_completed message" do
      before do
        running_command_payload = {:type => "running_command", :hostname => "host"}
        complete_payload = {:type => "command_completed", :hostname => "host"}
        allow(protocol).to receive(:receive_payloads).and_yield(Yajl::Encoder.encode(running_command_payload))
          .and_yield(Yajl::Encoder.encode(complete_payload))
      end

      it "writes to console" do
        expect($stdout).to receive(:write).at_least(:twice).with(/host/)
        @service.run @command
      end

      it "disconnect since there is no host running command anymore" do
        expect(protocol).to receive(:disconnect)
        @service.run @command
      end
    end
  end
end
