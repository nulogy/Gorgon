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
      bunny.should_receive(:exchange).with("name", anything).and_return(exchange)
      Yajl::Encoder.should_receive(:encode).with(@running_response).and_return :json_msg
      exchange.should_receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end

    it "runs 'gem <command> gorgon' using popen4" do
      Open4.should_receive(:popen4).with("gem cmd gorgon").and_return([1, stdin, stdout, stderr])
      @handler.handle payload, {}
    end

    it "uses binary gem from configuration if this was specified" do
      Open4.should_receive(:popen4).with("path/to/gem cmd gorgon").and_return([1, stdin, stdout, stderr])
      @handler.handle payload, {:bin_gem_path => "path/to/gem"}
    end

    it "waits for the command to finish" do
      Open4.should_receive(:popen4).ordered
      Process.should_receive(:waitpid2).with(1).ordered.and_return([nil, status])
      @handler.handle payload, {}
    end

    it "closes stding and reads stdout and stderr from process" do
      stdin.should_receive(:close)
      stdout.should_receive(:read)
      stderr.should_receive(:read)
      @handler.handle payload, {}
    end

    it "sends 'command_completed' message when exitstatus is 0" do
      response = {:type => :command_completed, :hostname => Socket.gethostname,
        :command => "gem cmd gorgon", :stdout => "output", :stderr => "errors" }
      Yajl::Encoder.should_receive(:encode).once.ordered.with(@running_response)
      Yajl::Encoder.should_receive(:encode).once.ordered.with(response).and_return :json_msg
      exchange.should_receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end

    it "stops bunny and exit if exitstatus is 0" do
      bunny.should_receive(:stop).once.ordered
      @handler.should_receive(:exit).once.ordered
      @handler.handle payload, {}
    end

    it "sends 'command_failed' message when exitstatus is not 0" do
      status.should_receive(:exitstatus).and_return(99)
      response = {:type => :command_failed, :hostname => Socket.gethostname,
        :command => "gem cmd gorgon", :stdout => "output", :stderr => "errors" }
      Yajl::Encoder.should_receive(:encode).with(response).and_return :json_msg
      exchange.should_receive(:publish).with(:json_msg)
      @handler.handle payload, {}
    end
  end

  def stub_methods
    Open4.stub(:popen4).and_return([1, stdin, stdout, stderr])
    Process.stub(:waitpid2).and_return([nil, status])
    Yajl::Encoder.stub(:encode).and_return :json_msg
    @handler.stub(:exit)
  end
end
