require 'gorgon/worker'

class FakeAmqp
  def initialize mock_queue, mock_exchange
    @mock_queue = mock_queue
    @mock_exchange = mock_exchange
  end

  def start_worker queue_name, exchange_name
    yield @mock_queue, @mock_exchange
  end
end

describe Worker do
  WORKER_ID = 1
  let(:file_queue) { double("Queue") }
  let(:reply_exchange) { double("Exchange") }
  let(:fake_amqp) { fake_amqp = FakeAmqp.new file_queue, reply_exchange }
  let(:test_runner) { double("Test Runner") }
  let(:callback_handler) { stub("Callback Handler", :before_start => nil, :after_complete => nil) }

  let(:params) {
    {
      :amqp => fake_amqp,
      :file_queue_name => "queue",
      :reply_exchange_name => "exchange",
      :worker_id => WORKER_ID,
      :test_runner => test_runner,
      :callback_handler => callback_handler
    }
  }

  describe '#work' do
    it 'should do nothing if the file queue is empty' do
      file_queue.should_receive(:pop).and_return(nil)

      worker = Worker.new params
      worker.work
    end

    it "should send start message when file queue is not empty" do
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      reply_exchange.should_receive(:publish) do |msg|
        msg[:action].should == :start
        msg[:filename].should == 'testfile1'
      end
      reply_exchange.should_receive(:publish).with(any_args())

      test_runner.should_receive(:run_file).with("testfile1").and_return({:type => :pass, :time => 0})

      worker = Worker.new params

      worker.work
    end

    it "should send finish message when test run is successful" do
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      reply_exchange.should_receive(:publish).once
      reply_exchange.should_receive(:publish) do |msg|
        msg[:action].should == :finish
        msg[:type].should == :pass
        msg[:filename].should == 'testfile1'
      end

      test_runner.should_receive(:run_file).with('testfile1').and_return({:type => :pass, :time => 0})

      worker = Worker.new params

      worker.work
    end

    it "should send finish message when test run has failures" do
      failures = stub

      file_queue.should_receive(:pop).and_return("testfile1", nil)

      reply_exchange.should_receive(:publish).once
      reply_exchange.should_receive(:publish) do |msg|
        msg[:action].should == :finish
        msg[:type].should == :fail
        msg[:filename].should == 'testfile1'
        msg[:failures].should == failures
      end

      test_runner.should_receive(:run_file).and_return({:type => :fail, :time => 0, :failures => failures})

      worker = Worker.new params

      worker.work
    end

    it "should notify the callback framework that it has started" do
      file_queue.stub(:pop => nil)
      callback_handler.should_receive(:before_start)

      worker = Worker.new params

      worker.work
    end

    it "should notify the callback framework when it finishes" do
      file_queue.stub(:pop => nil)
      callback_handler.should_receive(:after_complete)

      worker = Worker.new params

      worker.work
    end

  end

end
