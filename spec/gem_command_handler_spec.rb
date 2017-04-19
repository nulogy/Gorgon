require 'gorgon/gem_command_handler'

describe Gorgon::GemCommandHandler do
  let(:exchange) { double("GorgonBunny Exchange", :publish => nil) }
  let(:bunny) { double("GorgonBunny", :exchange => exchange, :stop => nil) }

  let(:payload) {
      {:type => :update, :reply_exchange_name => "name",
                                         :body => {:gem_command => "cmd"}}
  }
  let(:stdin) { double("IO object", :close => nil)}
  let(:stdout) { double("IO object", :read => "output", :close => nil)}
  let(:stderr) { double("IO object", :read => "errors", :close => nil)}
  let(:status) { double("Process Status", :exitstatus => 0)}

  describe "#handle" do
    before do
      @handler = Gorgon::GemCommandHandler.new bunny
      @running_response = {:type => :running_command, :hostname => Socket.gethostname}
      stub_methods
    end

    it "publishes 'running_command' message" do
      expect(bunny).to receive(:exchange).with("name", anything).and_return(exchange)
      expect(Yajl::Encoder).to receive(:encode).with(@running_response).and_return :json_msg
      expect(exchange).to receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end

    it "runs 'gem <command> gorgon' using popen4" do
      expect(Open4).to receive(:popen4).with("gem cmd gorgon").and_return([1, stdin, stdout, stderr])
      @handler.handle payload, {}
    end

    it "uses binary gem from configuration if this was specified" do
      expect(Open4).to receive(:popen4).with("path/to/gem cmd gorgon").and_return([1, stdin, stdout, stderr])
      @handler.handle payload, {:bin_gem_path => "path/to/gem"}
    end

    it "waits for the command to finish" do
      expect(Open4).to receive(:popen4).ordered
      expect(Process).to receive(:waitpid2).with(1).ordered.and_return([nil, status])
      @handler.handle payload, {}
    end

    it "closes stding and reads stdout and stderr from process" do
      expect(stdin).to receive(:close)
      expect(stdout).to receive(:read)
      expect(stderr).to receive(:read)
      @handler.handle payload, {}
    end

    it "sends 'command_completed' message when exitstatus is 0" do
      response = {:type => :command_completed, :hostname => Socket.gethostname,
        :command => "gem cmd gorgon", :stdout => "output", :stderr => "errors" }
      expect(Yajl::Encoder).to receive(:encode).once.ordered.with(@running_response)
      expect(Yajl::Encoder).to receive(:encode).once.ordered.with(response).and_return :json_msg
      expect(exchange).to receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end

    it "stops bunny and exit if exitstatus is 0" do
      expect(bunny).to receive(:stop).once.ordered
      expect(@handler).to receive(:exit).once.ordered
      @handler.handle payload, {}
    end

    it "sends 'command_failed' message when exitstatus is not 0" do
      expect(status).to receive(:exitstatus).and_return(99)
      response = {:type => :command_failed, :hostname => Socket.gethostname,
        :command => "gem cmd gorgon", :stdout => "output", :stderr => "errors" }
      expect(Yajl::Encoder).to receive(:encode).with(response).and_return :json_msg
      expect(exchange).to receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end
  end

  def stub_methods
    allow(Open4).to receive(:popen4).and_return([1, stdin, stdout, stderr])
    allow(Process).to receive(:waitpid2).and_return([nil, status])
    allow(Yajl::Encoder).to receive(:encode).and_return :json_msg
    allow(@handler).to receive(:exit)
  end
end
