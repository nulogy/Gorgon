require 'gorgon/update_handler'

describe UpdateHandler do
  let(:exchange) { stub("Bunny Exchange", :publish => nil) }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange) }

  let(:payload) {
      {:type => :update, :reply_exchange_name => "name",
                                         :body => {:version => "1.2.3"}}
    }

  describe "#handle" do
    before do
      @handler = UpdateHandler.new bunny
    end

    it "publishes 'updating' message" do
      bunny.should_receive(:exchange).with("name", anything).and_return(exchange)
      response = {:type => :updating, :hostname => Socket.gethostname}
      Yajl::Encoder.should_receive(:encode).with(response).and_return :json_msg
      exchange.should_receive(:publish).with(:json_msg)
      @handler.handle payload
    end
  end
end
