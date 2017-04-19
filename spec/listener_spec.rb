require 'gorgon/listener'

describe Gorgon::Listener do
  let(:connection_information) { double }
  let(:queue) { double("GorgonBunny Queue", :bind => nil, :name => "some supposedly unique string") }
  let(:exchange) { double("GorgonBunny Exchange", :publish => nil) }
  let(:bunny) { double("GorgonBunny", :start => nil, :queue => queue, :exchange => exchange) }
  let(:logger) { double("Logger", :info => true, :datetime_format= => "")}
  let(:sync_execution_context) { double("Sync Execution Context", success: true, command: "command", output: "some output", errors: "some errors")}

  before do
    allow(Logger).to receive(:new).and_return(logger)
    allow(GorgonBunny).to receive(:new).and_return(bunny)
    allow_any_instance_of(Gorgon::Listener).to receive(:configuration).and_return({})
    allow_any_instance_of(Gorgon::Listener).to receive(:connection_information).and_return(connection_information)
  end

  describe "logging to a file" do
    context "passing a log file path in the configuration" do
      before do
        allow_any_instance_of(Gorgon::Listener).to receive(:configuration).and_return({:log_file => 'listener.log'})
      end

      it "should use 'log_file' from the configuration as the log file" do
        expect(Logger).to receive(:new).with('listener.log', anything, anything)
        Gorgon::Listener.new
      end

      it "should log to 'log_file'" do
        expect(logger).to receive(:info).with(/Listener.*initializing/)

        Gorgon::Listener.new
      end
    end

    context "passing a literal '-'' as the path in the configuration" do
      before do
        allow_any_instance_of(Gorgon::Listener).to receive(:configuration).and_return({:log_file => "-"})
      end

      it "logs to stdout" do
        expect(Logger).to receive(:new).with($stdout)
        Gorgon::Listener.new
      end
    end

    context "without specifying a log file path" do
      it "should not log" do
        expect(Logger).not_to receive(:new)
        expect(logger).not_to receive(:info)

        Gorgon::Listener.new
      end
    end
  end

  context "initialized" do
    let(:listener) { Gorgon::Listener.new }

    describe "#connect" do
      it "connects" do
        expect(GorgonBunny).to receive(:new).with(connection_information).and_return(bunny)
        expect(bunny).to receive(:start)

        listener.connect
      end
    end

    describe "#initialize_personal_job_queue" do
      it "creates the job queue" do
        allow(UUIDTools::UUID).to receive(:timestamp_create).and_return("abcd1234")

        expect(bunny).to receive(:queue).with("job_queue_abcd1234", :auto_delete => true)
        listener.initialize_personal_job_queue
      end

      it "builds job_exchange_name using cluster_id from configuration" do
        allow_any_instance_of(Gorgon::Listener).to receive(:configuration).and_return(:cluster_id => 'cluster5')
        expect(bunny).to receive(:exchange).with('gorgon.jobs.cluster5', anything).and_return(exchange)
        listener.initialize_personal_job_queue
      end

      it "binds the exchange to the queue. Uses gorgon.jobs if there is no job_exchange_name in configuration" do
        expect(bunny).to receive(:exchange).with("gorgon.jobs", :type => :fanout).and_return(exchange)
        expect(queue).to receive(:bind).with(exchange)
        listener.initialize_personal_job_queue
      end
    end

    describe "#announce_readiness_to_originators" do
      it "publishes data to the originator exchange" do
        originator_exchange = double

        expect(bunny).to receive(:exchange).with("gorgon.originators", :type => :fanout).and_return(originator_exchange)
        expect(originator_exchange).to receive(:publish).with({:listener_queue_name => "some supposedly unique string"}.to_json)

        listener.announce_readiness_to_originators
      end
    end

    describe "#poll" do

      let(:empty_queue) { [nil, nil, nil] }
      let(:job_payload) { [nil, nil, Yajl::Encoder.encode({:type => "job_definition"})] }
      before do
        allow(listener).to receive(:run_job)
      end

      context "empty queue" do
        before do
          allow(queue).to receive(:pop).and_return(empty_queue)
        end

        it "checks the job queue" do
          expect(queue).to receive(:pop).and_return(empty_queue)
          listener.poll
        end

        it "returns false" do
          expect(listener.poll).to be_falsey
        end
      end

      context "job pending on queue" do
        before do
          allow(queue).to receive(:pop).and_return(job_payload)
        end

        it "starts a new job when there is a job payload" do
          expect(queue).to receive(:pop).and_return(job_payload)
          expect(listener).to receive(:run_job).with({:type => "job_definition"})
          listener.poll
        end

        it "returns true" do
          expect(listener.poll).to be_truthy
        end
      end

      context "ping message pending on queue" do
        let(:ping_payload) { [nil, nil, Yajl::Encoder.encode({:type => "ping", :reply_exchange_name => "name", :body => {}}) ] }

        before do
          allow(queue).to receive(:pop).and_return(ping_payload)
          allow(listener).to receive(:configuration).and_return({:worker_slots => 3})
       end

        it "publishes ping_response message with Gorgon's version" do
          expect(listener).not_to receive(:run_job)
          expect(bunny).to receive(:exchange).with("name", anything).and_return(exchange)
          response = {:type => "ping_response", :hostname => Socket.gethostname,
            :version => Gorgon::VERSION, :worker_slots => 3}
          expect(exchange).to receive(:publish).with(Yajl::Encoder.encode(response))
          listener.poll
        end
      end

      context "gem_command message pending on queue" do
        let(:command) { "install" }

        let(:payload) {
            {:type => "gem_command", :reply_exchange_name => "name",
              :body => {:command => command}}
        }

        let(:gem_command_handler) { double("GemCommandHandler", :handle => nil)  }
        let(:configuration) { {:worker_slots => 3} }
        before do
          allow(queue).to receive(:pop).and_return([nil, nil, Yajl::Encoder.encode(payload)])
          allow(listener).to receive(:configuration).and_return(configuration)
        end

        it "calls GemCommandHandler#handle and pass payload" do
          expect(Gorgon::GemCommandHandler).to receive(:new).with(bunny).and_return gem_command_handler
          expect(gem_command_handler).to receive(:handle).with payload, configuration
          listener.poll
        end
      end
    end

    describe "#run_job" do
      let(:payload) {{
          :sync => {:source_tree_path => "path/to/source", :exclude => ["log"]}, :callbacks => {:a_callback => "path/to/callback"}
        }}

      let(:syncer) { double("SourceTreeSyncer")}
      let(:process_status) { double("Process Status", :exitstatus => 0)}
      let(:callback_handler) { double("Callback Handler", :after_sync => nil) }
      let(:stdin) { double("IO object", :write => nil, :close => nil)}
      let(:stdout) { double("IO object", :read => nil, :close => nil)}
      let(:stderr) { double("IO object", :read => nil, :close => nil)}

      before do
        stub_classes
        @listener = Gorgon::Listener.new
      end

      it "copy source tree" do
        expect(Gorgon::SourceTreeSyncer).to receive(:new).once.
          with(source_tree_path: "path/to/source", exclude: ["log"]).
          and_return(syncer)
        expect(syncer).to receive(:pull).and_yield(sync_execution_context)
        @listener.run_job(payload)
      end

      context "syncer#sync fails" do
        before do
          allow(sync_execution_context).to receive(:success).and_return false
          allow(sync_execution_context).to receive(:output).and_return "some output"
          allow(sync_execution_context).to receive(:errors).and_return "some errors"
        end

        it "aborts current job" do
          expect(callback_handler).not_to receive(:after_sync)
          @listener.run_job(payload)
        end

        it "sends message to originator with output and errors from syncer" do
          expect(@listener).to receive(:send_crash_message).with(exchange, "some output", "some errors")
          @listener.run_job(payload)
        end
      end

      context "Worker Manager crashes" do
        before do
          expect(process_status).to receive(:exitstatus).and_return 2, 2
        end

        it "report_crash with pid, exitstatus, stdout and stderr outputs" do
          expect(@listener).to receive(:report_crash).with(exchange,
                                                       :out_file => Gorgon::WorkerManager::STDOUT_FILE,
                                                       :err_file => Gorgon::WorkerManager::STDERR_FILE,
                                                       :footer_text => Gorgon::Listener::ERROR_FOOTER_TEXT)
          @listener.run_job(payload)
        end
      end

      it "creates a CallbackHandler object using callbacks passed in payload" do
        expect(Gorgon::CallbackHandler).to receive(:new).once.with({:a_callback => "path/to/callback"}).and_return(callback_handler)
        @listener.run_job(payload)
      end

      it "calls after_sync callback" do
        expect(callback_handler).to receive(:after_sync).once
        @listener.run_job(payload)
      end
    end

    private

    def stub_classes
      allow(Gorgon::SourceTreeSyncer).to receive(:new).and_return syncer
      allow(syncer).to receive(:pull).and_yield(sync_execution_context)
      allow(Gorgon::CallbackHandler).to receive(:new).and_return callback_handler
      allow(Open4).to receive(:popen4).and_return([1, stdin, stdout, stderr])
      allow(Process).to receive(:waitpid2).and_return([0, process_status])
      allow(Socket).to receive(:gethostname).and_return("hostname")
    end
  end
end
