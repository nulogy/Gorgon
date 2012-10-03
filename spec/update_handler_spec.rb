require 'gorgon/update_handler'

describe UpdateHandler do
  let(:exchange) { stub("Bunny Exchange", :publish => nil) }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange) }

  let(:payload) {
      {:type => :update, :reply_exchange_name => "name",
                                         :body => {:version => "1.2.3"}}
  }
  let(:stdin) { stub("IO object", :close => nil)}
  let(:stdout) { stub("IO object", :read => nil, :close => nil)}
  let(:stderr) { stub("IO object", :read => nil, :close => nil)}
  let(:status) { stub("Process Status", :exitstatus => 0)}

  describe "#handle" do
    before do
      @handler = UpdateHandler.new bunny
      stub_methods
    end

    it "publishes 'updating' message" do
      bunny.should_receive(:exchange).with("name", anything).and_return(exchange)
      response = {:type => :updating, :hostname => Socket.gethostname}
      Yajl::Encoder.should_receive(:encode).with(response).and_return :json_msg
      exchange.should_receive(:publish).with(:json_msg)
      @handler.handle payload
    end
  end

  def stub_methods
    Open4.stub!(:popen4).and_return([1, stdin, stdout, stderr])
    Process.stub!(:waitpid2).and_return([nil, status])
  end
end
