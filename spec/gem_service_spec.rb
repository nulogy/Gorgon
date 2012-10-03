require 'gorgon/gem_service'

describe GemService do
  let(:configuration){ {:connection => {:host => "host"}, :originator_log_file => "file.log"}}
  let(:protocol) { stub("OriginatorProtocol", :connect => nil,
                        :receive_payloads => nil, :disconnect => nil,
                        :send_message_to_listeners => nil)}
  let(:logger){ stub("Originator Logger", :log => nil, :log_message => nil)}

  before do
    $stdout.stub!(:write)
    GemService.any_instance.stub(:load_configuration_from_file).and_return configuration
    EM.stub!(:run).and_yield
    EM.stub!(:add_periodic_timer).and_yield
    OriginatorLogger.stub!(:new).and_return logger
    OriginatorProtocol.stub!(:new).and_return(protocol)
    @service = GemService.new
    @command = "install"
  end

  describe "#run" do
    it "runs EventMachine loop and connect using configuration[:connection]" do
      EM.should_receive(:run)
      protocol.should_receive(:connect).once.ordered.with({:host => "host"}, anything)
      @service.run @command
    end

    it "calls Protocol#send_message_to_listeners with version number" do
      protocol.should_receive(:send_message_to_listeners).with(:gem_command, :command => @command)
      @service.run @command
    end

    it "adds a periodic timer that checks if there is any listener running command" do
      EM.should_receive(:add_periodic_timer).with(GemService::TIMEOUT)
      @service.run @command
    end

    context "when it receives an running_command message" do
      before do
        payload = {:type => "running_command", :hostname => "host"}
        protocol.stub!(:receive_payloads).and_yield Yajl::Encoder.encode(payload)
      end

      it "writes to console" do
        $stdout.should_receive(:write).with(/host/)
        @service.run @command
      end

      it "won't diconnect as long as there is a host running_command" do
        protocol.should_not_receive(:disconnect)
        @service.run @command
      end
    end

    context "when it receives an command_completed message" do
      before do
        running_command_payload = {:type => "running_command", :hostname => "host"}
        complete_payload = {:type => "command_completed", :hostname => "host"}
        protocol.stub!(:receive_payloads).and_yield(Yajl::Encoder.encode(running_command_payload))
          .and_yield(Yajl::Encoder.encode(complete_payload))
      end

      it "writes to console" do
        $stdout.should_receive(:write).twice.with(/host/)
        @service.run @command
      end

      it "disconnect since there is no host running command anymore" do
        protocol.should_receive(:disconnect)
        @service.run @command
      end
    end
  end
end
