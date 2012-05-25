require 'gorgon/listener'

describe Listener do
  let(:connection_information) { double }
  let(:queue) { stub("Bunny Queue", :bind => nil) }
  let(:exchange) { stub("Bunny Exchange") }
  let(:bunny) { stub("Bunny", :start => nil, :queue => queue, :exchange => exchange) }

  before do
    Bunny.stub(:new).and_return(bunny)
    Listener.any_instance.stub(:configuration => {})
    Listener.any_instance.stub(:connection_information => connection_information)
  end

  describe "initialization" do

    before do
      Listener.any_instance.stub(:connect => nil, :initialize_personal_job_queue => nil)
    end

    it "connects" do
      Listener.any_instance.should_receive(:connect)
      Listener.new
    end

    it "initializes the personal job queue" do
      Listener.any_instance.should_receive(:initialize_personal_job_queue)
      Listener.new
    end
  end

  describe "logging to a file" do
    before do
      @stub_logger = stub :info => true, :datetime_format= => ""
      Logger.stub(:new).and_return(@stub_logger)
    end

    context "passing a log file path in the configuration" do
      before do
        Listener.any_instance.stub(:configuration).and_return({:log_file => 'listener.log'})
      end

      it "should use 'log_file' from the configuration as the log file" do
        Logger.should_receive(:new).with('listener.log')
        Listener.new
      end

      it "should log to 'log_file'" do
        @stub_logger.should_receive(:info).with("Listener initialized")

        Listener.new
      end
    end

    context "passing a literal '-'' as the path in the configuration" do
      before do
        Listener.any_instance.stub(:configuration).and_return({:log_file => "-"})
      end

      it "logs to stdout" do
        Logger.should_receive(:new).with($stdout)
        Listener.new
      end
    end

    context "without specifying a log file path" do
      it "should not log" do
        Logger.should_not_receive(:new)
        @stub_logger.should_not_receive(:info)

        Listener.new
      end
    end
  end

  context "initialized" do
    let(:listener) { Listener.new }

    describe "#connect" do
      it "connects" do
        Bunny.should_receive(:new).with(connection_information).and_return(bunny)
        bunny.should_receive(:start)

        listener.connect
      end
    end

    describe "#initialize_personal_job_queue" do
      it "creates the job queue" do
        bunny.should_receive(:queue).with("", :exclusive => true)
        listener.initialize_personal_job_queue
      end

      it "binds the exchange to the queue" do
        bunny.should_receive(:exchange).with("gorgon.jobs", :type => :fanout).and_return(exchange)
        queue.should_receive(:bind).with(exchange)
        listener.initialize_personal_job_queue
      end
    end

    describe "#poll" do

      let(:empty_queue) { {:payload => :queue_empty} }
      let(:job_payload) { {:payload => "Job"} }
      before do
        listener.stub(:start_job)
      end

      context "empty queue" do
        before do
          queue.stub(:pop => empty_queue)
        end

        it "checks the job queue" do
          queue.should_receive(:pop).and_return(empty_queue)
          listener.poll
        end

        it "returns false" do
          listener.poll.should be_false
        end
      end

      context "job pending on queue" do
        before do
          queue.stub(:pop => job_payload)
        end

        it "starts a new job when there is a job payload" do
          queue.should_receive(:pop).and_return(job_payload)
          listener.should_receive(:start_job).with(job_payload[:payload])
          listener.poll
        end

        it "returns true" do
          listener.poll.should be_true
        end
      end
    end
  end
end
