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
  let(:reply_exchange) { double("Exchange", :publish => nil) }
  let(:fake_amqp) { fake_amqp = FakeAmqp.new file_queue, reply_exchange }
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
      stub_const("MiniTestRunner", :mini_test_runner)
      stub_const("MiniTest", :test)
      Worker.any_instance.stub(:initialize_logger)
      @worker = Worker.new params
      @worker.stub!(:require_relative)
    end

    it 'should do nothing if the file queue is empty' do
      file_queue.should_receive(:pop).and_return(nil)

      @worker.work
    end

    it "should send start message when file queue is not empty" do
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      reply_exchange.should_receive(:publish) do |msg|
        msg[:action].should == :start
        msg[:filename].should == 'testfile1'
      end
      reply_exchange.should_receive(:publish).with(any_args())

      TestRunner.stub!(:run_file).and_return({:type => :pass, :time => 0})

      @worker.work
    end

    it "should send finish message when test run is successful" do
      file_queue.should_receive(:pop).and_return("testfile1", nil)

      reply_exchange.should_receive(:publish).once
      reply_exchange.should_receive(:publish) do |msg|
        msg[:action].should == :finish
        msg[:type].should == :pass
        msg[:filename].should == 'testfile1'
      end

      TestRunner.stub!(:run_file).and_return({:type => :pass, :time => 0})

      @worker.work
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

      TestRunner.stub!(:run_file).and_return({:type => :fail, :time => 0, :failures => failures})

      @worker.work
    end

    it "should notify the callback framework that it has started" do
      file_queue.stub(:pop => nil)
      callback_handler.should_receive(:before_start)

      @worker.work
    end

    it "should notify the callback framework when it finishes" do
      file_queue.stub(:pop => nil)
      callback_handler.should_receive(:after_complete)

      @worker.work
    end

    describe "shoosing right runner" do
      before :all do
        # we assume MiniTest is defined (default ruby 1.9), but let's define it just in case
        MiniTest ||= 1
        Temp = MiniTest
      end

      before do
        stub_const("TestUnitRunner", :test_unit_runner)
        stub_const("RspecRunner", :rspec_runner)

        # ruby 1.9 defines MiniTest by default, so let's remove it for these test cases
        Object.send(:remove_const, :MiniTest)
        file_queue.stub!(:pop).and_return("file_test.rb", nil)
        File.stub!(:read).and_return("")
      end

      it "runs file using TestUnitRunner when file doesn't end in _spec and Test is defined" do
        stub_const("Test", :test_unit)

        @worker.should_receive(:require_relative).with "test_unit_runner"
        TestRunner.should_receive(:run_file).with("file_test.rb", TestUnitRunner).and_return({})

        @worker.work
      end

      it "runs file using RspecRunner when file finishes in _spec.rb and Rspec is defined" do
        file_queue.stub!(:pop).and_return("file_spec.rb", nil)

        @worker.should_receive(:require_relative).with "rspec_runner"
        TestRunner.should_receive(:run_file).with("file_spec.rb", RspecRunner).and_return({})

        @worker.work
      end

      it "runs file using MiniTest when file name doesn't end in _spec.rb and MiniTest is defined" do
        MiniTest = Temp

        @worker.should_receive(:require_relative).with "mini_test_runner"
        TestRunner.should_receive(:run_file).with("file_test.rb", MiniTestRunner).and_return({})
        @worker.work
      end

      it "runs file using TestUnitRunner when file doesn't end in _spec.rb, MiniTest is defined but project is using test-unit gem" do
        MiniTest = Temp
        File.stub!(:read).and_return("test-unit")
        stub_const("Test", :test_unit)

        @worker.should_receive(:require_relative).with "test_unit_runner"
        TestRunner.should_receive(:run_file).with("file_test.rb", TestUnitRunner).and_return({})

        @worker.work
      end

      it "uses UnknownRunner if the framework is unknown" do
        stub_const("UnknownRunner", :unknown_runner)
        file_queue.stub!(:pop).and_return("file.rb", nil)

        @worker.should_receive(:require_relative).with "unknown_runner"
        TestRunner.should_receive(:run_file).with("file.rb", UnknownRunner).and_return({})

        @worker.work
      end

      after do
        MiniTest ||= Temp
      end
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
