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

describe Gorgon::Worker do
  WORKER_ID = 1
  let(:file_queue) { double("Queue") }
  let(:reply_exchange) { double("Exchange", :publish => nil) }
  let(:fake_amqp) { fake_amqp = FakeAmqp.new file_queue, reply_exchange }
  let(:callback_handler) { double("Callback Handler", :before_start => nil, :after_complete => nil) }
  let(:job_definition) {double("JobDefinition", :callbacks => ["/path/to/callback"],
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
      allow(Gorgon::AmqpService).to receive(:new).and_return fake_amqp
      allow(Gorgon::CallbackHandler).to receive(:new).and_return callback_handler
      allow(Gorgon::Worker).to receive(:new)
    end

    it "redirects output to a file since writing to a pipe may block when pipe is full" do
      expect(File).to receive(:open).with(Gorgon::Worker.output_file(1, :out), 'w').and_return(:file1)
      expect(STDOUT).to receive(:reopen).with(:file1)
      expect(File).to receive(:open).with(Gorgon::Worker.output_file(1, :err), 'w').and_return(:file2)
      expect(STDERR).to receive(:reopen).with(:file2)
      Gorgon::Worker.build 1, config
    end

    it "use STDOUT#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      expect(STDOUT).to receive(:reopen).once.ordered
      expect(STDOUT).to receive(:sync=).with(true).once.ordered
      Gorgon::Worker.build 1, config
    end

    it "use STDERR#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      expect(STDERR).to receive(:reopen).once.ordered
      expect(STDERR).to receive(:sync=).with(true).once.ordered
      Gorgon::Worker.build 1, config
    end

    it "creates a JobDefinition using a payload written to stdin" do
      expect(STDIN).to receive(:read).and_return '{ "key": "value" }'
      expect(Gorgon::JobDefinition).to receive(:new).with({:key => "value"}).and_return job_definition
      Gorgon::Worker.build 1, config
    end

    it "creates a new worker" do
      allow(Gorgon::JobDefinition).to receive(:new).and_return job_definition
      expect(Gorgon::Worker).to receive(:new).with(params)
      Gorgon::Worker.build 1, config
    end
  end

  describe '#work' do
    before do
      stub_const("MiniTestRunner", :mini_test_runner)
      stub_const("MiniTest", :test)
      allow_any_instance_of(Gorgon::Worker).to receive(:initialize_logger)
      @worker = Gorgon::Worker.new params
      allow(@worker).to receive(:require_relative)
    end

    it 'should do nothing if the file queue is empty' do
      expect(file_queue).to receive(:pop).and_return(nil)

      @worker.work
    end

    it "should send start message when file queue is not empty" do
      expect(file_queue).to receive(:pop).and_return("testfile1", nil)

      expect(reply_exchange).to receive(:publish) do |msg|
        expect(msg[:action]).to eq(:start)
        expect(msg[:filename]).to eq('testfile1')
      end
      expect(reply_exchange).to receive(:publish).with(any_args())

      allow(Gorgon::TestRunner).to receive(:run_file).and_return({:type => :pass, :time => 0})

      @worker.work
    end

    it "should send finish message when test run is successful" do
      expect(file_queue).to receive(:pop).and_return("testfile1", nil)

      expect(reply_exchange).to receive(:publish).once
      expect(reply_exchange).to receive(:publish) do |msg|
        expect(msg[:action]).to eq(:finish)
        expect(msg[:type]).to eq(:pass)
        expect(msg[:filename]).to eq('testfile1')
      end

      allow(Gorgon::TestRunner).to receive(:run_file).and_return({:type => :pass, :time => 0})

      @worker.work
    end

    it "should send finish message when test run has failures" do
      failures = double

      expect(file_queue).to receive(:pop).and_return("testfile1", nil)

      expect(reply_exchange).to receive(:publish).once
      expect(reply_exchange).to receive(:publish) do |msg|
        expect(msg[:action]).to   eq(:finish)
        expect(msg[:type]).to     eq(:fail)
        expect(msg[:filename]).to eq('testfile1')
        expect(msg[:failures]).to eq(failures)
      end

      expect(Gorgon::TestRunner).to receive(:run_file).and_return({:type => :fail, :time => 0, :failures => failures})

      @worker.work
    end

    it "should notify the callback framework that it has started" do
      allow(file_queue).to receive(:pop).and_return(nil)
      expect(callback_handler).to receive(:before_start)

      @worker.work
    end

    it "should notify the callback framework when it finishes" do
      allow(file_queue).to receive(:pop).and_return(nil)
      expect(callback_handler).to receive(:after_complete)

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
        allow(file_queue).to receive(:pop).and_return("file_test.rb", nil)
        allow(File).to receive(:read).and_return("")
      end

      it "runs file using TestUnitRunner when file doesn't end in _spec and Test is defined" do
        stub_const("Test", :test_unit)

        expect(@worker).to receive(:require_relative).with "test_unit_runner"
        expect(Gorgon::TestRunner).to receive(:run_file).with("file_test.rb", TestUnitRunner).and_return({})

        @worker.work
      end

      it "runs file using RspecRunner when file finishes in _spec.rb and Rspec is defined" do
        allow(file_queue).to receive(:pop).and_return("file_spec.rb", nil)

        expect(@worker).to receive(:require_relative).with "rspec_runner"
        expect(Gorgon::TestRunner).to receive(:run_file).with("file_spec.rb", RspecRunner).and_return({})

        @worker.work
      end

      it "runs file using MiniTest when file name doesn't end in _spec.rb and MiniTest is defined" do
        MiniTest = Temp

        expect(@worker).to receive(:require_relative).with "mini_test_runner"
        expect(Gorgon::TestRunner).to receive(:run_file).with("file_test.rb", MiniTestRunner).and_return({})
        @worker.work
      end

      it "runs file using TestUnitRunner when file doesn't end in _spec.rb, MiniTest is defined but project is using test-unit gem" do
        MiniTest = Temp
        allow(File).to receive(:read).and_return("test-unit")
        stub_const("Test", :test_unit)

        expect(@worker).to receive(:require_relative).with "test_unit_runner"
        expect(Gorgon::TestRunner).to receive(:run_file).with("file_test.rb", TestUnitRunner).and_return({})

        @worker.work
      end

      it "uses UnknownRunner if the framework is unknown" do
        stub_const("UnknownRunner", :unknown_runner)
        allow(file_queue).to receive(:pop).and_return("file.rb", nil)

        expect(@worker).to receive(:require_relative).with "unknown_runner"
        expect(Gorgon::TestRunner).to receive(:run_file).with("file.rb", UnknownRunner).and_return({})

        @worker.work
      end

      after do
        MiniTest ||= Temp
      end
    end

  end

  private

  def stub_streams
    allow(STDIN).to  receive(:read).and_return "{}"
    allow(STDOUT).to receive(:reopen)
    allow(STDERR).to receive(:reopen)
    allow(STDOUT).to receive(:sync)
    allow(STDERR).to receive(:sync)
  end
end
