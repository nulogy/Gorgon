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
  let(:job_definition) {stub("JobDefinition", :callbacks => ["/path/to/callback"],
                             :file_queue_name => "queue",
                             :reply_exchange_name => "exchange")}

  let(:params) {
    {
      :amqp => fake_amqp,
      :file_queue_name => "queue",
      :reply_exchange_name => "exchange",
      :worker_id => WORKER_ID,
      :callback_handler => callback_handler,
      :log_file => "path/to/log_file"
    }
  }

  describe ".build" do
    let(:config) { {:connection => "", :log_file => "path/to/log_file"} }
    before do
      stub_streams
      AmqpService.stub!(:new).and_return fake_amqp
      CallbackHandler.stub!(:new).and_return callback_handler
      Worker.stub!(:new)
    end

    it "redirects output to a file since writing to a pipe may block when pipe is full" do
      File.should_receive(:open).with(Worker.output_file(1, :out), 'w').and_return(:file1)
      STDOUT.should_receive(:reopen).with(:file1)
      File.should_receive(:open).with(Worker.output_file(1, :err), 'w').and_return(:file2)
      STDERR.should_receive(:reopen).with(:file2)
      Worker.build 1, config
    end

    it "use STDOUT#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      STDOUT.should_receive(:reopen).once.ordered
      STDOUT.should_receive(:sync=).with(true).once.ordered
      Worker.build 1, config
    end

    it "use STDERR#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      STDERR.should_receive(:reopen).once.ordered
      STDERR.should_receive(:sync=).with(true).once.ordered
      Worker.build 1, config
    end

    it "creates a JobDefinition using a payload written to stdin" do
      STDIN.should_receive(:read).and_return '{ "key": "value" }'
      JobDefinition.should_receive(:new).with({:key => "value"}).and_return job_definition
      Worker.build 1, config
    end

    it "creates a new worker" do
      JobDefinition.stub!(:new).and_return job_definition
      Worker.should_receive(:new).with(params)
      Worker.build 1, config
    end
  end

  describe '#work' do
    before do
      stub_const("TestRunner", test_runner)
      Worker.any_instance.stub(:initialize_logger)
    end

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

      test_runner.should_receive(:run_file).with("testfile1", TestUnitRunner).and_return({:type => :pass, :time => 0})

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

      test_runner.should_receive(:run_file).with('testfile1', TestUnitRunner).and_return({:type => :pass, :time => 0})

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

  private

  def stub_streams
    STDIN.stub!(:read).and_return "{}"
    STDOUT.stub!(:reopen)
    STDERR.stub!(:reopen)
    STDOUT.stub!(:sync)
    STDERR.stub!(:sync)
  end
end
