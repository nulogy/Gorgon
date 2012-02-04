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

  describe '#work' do
    it 'should do nothing if the file queue is empty' do
      file_queue = stub(:pop => nil)
      fake_amqp = FakeAmqp.new file_queue, double
      worker = Worker.new fake_amqp, 'queue', 'exchange', WORKER_ID, double
      
      worker.work
    end

    it "should send start message when file queue is not empty" do
      file_queue = double
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      exchange = double
      exchange.should_receive(:publish) do |msg|
        msg[:action].should == :start
        msg[:filename].should == 'testfile1'
      end
      exchange.should_receive(:publish).with(any_args())

      test_runner = stub(:run_file => {:type => :pass, :time => 0})

      fake_amqp = FakeAmqp.new file_queue, exchange
      worker = Worker.new fake_amqp, 'queue', 'exchange', WORKER_ID, test_runner

      worker.work
    end

    it "should run the given file" do
      file_queue = double
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      test_runner = double
      test_runner.should_receive(:run_file).with('testfile1').and_return({:type => :pass, :time => 0})

      fake_amqp = FakeAmqp.new file_queue, stub(:publish => nil)
      worker = Worker.new fake_amqp, 'queue', 'exchange', WORKER_ID, test_runner

      worker.work
    end

    it "should send finish message when test run is successful" do
      file_queue = double
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      exchange = double
      exchange.should_receive(:publish).once
      exchange.should_receive(:publish) do |msg|
        msg[:action].should == :finish
        msg[:type].should == :pass
        msg[:filename].should == 'testfile1'
      end

      test_runner = stub(:run_file => {:type => :pass, :time => 0})

      fake_amqp = FakeAmqp.new file_queue, exchange
      worker = Worker.new fake_amqp, 'queue', 'exchange', WORKER_ID, test_runner

      worker.work
    end

    it "should send finish message when test run has failures" do
      failures = stub

      file_queue = double
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      exchange = double
      exchange.should_receive(:publish).once
      exchange.should_receive(:publish) do |msg|
        msg[:action].should == :finish
        msg[:type].should == :fail
        msg[:filename].should == 'testfile1'
        msg[:failures].should == failures
      end

      test_runner = stub(:run_file => {:type => :fail, :time => 0, :failures => failures})

      fake_amqp = FakeAmqp.new file_queue, exchange
      worker = Worker.new fake_amqp, 'queue', 'exchange', WORKER_ID, test_runner

      worker.work
    end

  end
  
end
