require 'gorgon/originator'
require File.expand_path("../support/stream_helpers", __FILE__)

describe Gorgon::Originator do
  include Gorgon::StreamHelpers
  let(:protocol){ double("Originator Protocol", :connect => nil, :publish_files => nil,
    :publish_job_to_all => nil, :publish_job_to_one => nil, :receive_payloads => nil, :cancel_job => nil,
    :disconnect => nil, :receive_new_listener_notifications => nil)}

  let(:configuration){ {:job => {}, :files => ["some/file"], :file_server => {:host => 'host-name'}}}
  let(:job_state){ double("JobState", :is_job_complete? => false, :file_finished => nil,
    :add_observer => nil)}
  let(:progress_bar_view){ double("Progress Bar View", :show => nil)}
  let(:originator_logger){ double("Originator Logger", :log => nil, :log_message => nil)}
  let(:source_tree_syncer) { double("Source Tree Syncer")}
  let(:sync_execution_context) { double("Sync Execution Context", success: true, command: "command")}
  let(:job_definition){ Gorgon::JobDefinition.new }

  before do
    allow(Gorgon::OriginatorLogger).to receive(:new).and_return originator_logger
    allow(Gorgon::SourceTreeSyncer).to receive(:new).and_return source_tree_syncer
    allow(source_tree_syncer).to receive(:push).and_return(sync_execution_context)
    allow(Dir).to receive(:[]).and_return(["file"])
    @originator = Gorgon::Originator.new
  end

  describe "#publish" do
    before do
      stub_methods
    end

    it "creates a JobState instance and passes total files" do
      allow(@originator).to receive(:files).and_return ["a file", "other file"]
      expect(Gorgon::JobState).to receive(:new).with(2).and_return job_state

      @originator.publish
    end

    it "propagates the success result of handle_reply" do
      expect(@originator.publish).to eq Gorgon::Originator::SPEC_SUCCESS_EXIT_STATUS
    end

    it "propagates the error result of handle_reply" do
      expect(Gorgon::OriginatorProtocol).to receive(:new).and_return(protocol)
      expect(protocol).to receive(:receive_payloads).and_yield(Yajl::Encoder.encode({:type => 'fail'}))

      silence_streams($stdout) do
        expect(@originator.publish).to eq Gorgon::Originator::SPEC_FAILURE_EXIT_STATUS
      end
    end

    it "creates a ProgressBarView and show" do
      allow(Gorgon::JobState).to receive(:new).and_return job_state
      expect(Gorgon::ProgressBarView).to receive(:new).with(job_state).and_return progress_bar_view
      expect(progress_bar_view).to receive(:show)
      @originator.publish
    end

    it "pushes source code" do
      expect(source_tree_syncer).to receive(:push).and_return(sync_execution_context)
      expect(sync_execution_context).to receive(:success).and_return true

      @originator.publish
    end

    it "errors and halts when there are no test files" do
      allow(Dir).to receive(:[]).and_return([])

      expect($stderr).to receive(:puts)
      expect(Gorgon::OriginatorProtocol).not_to receive(:new)
      expect(source_tree_syncer).not_to receive(:push)

      expect { @originator.publish }.to raise_error(SystemExit)
    end

    it "calls before_originate callback" do
      expect_any_instance_of(Gorgon::CallbackHandler).to receive(:before_originate)
      @originator.publish
    end

    it "uses results of before_originate callback to build a job_queue_name" do
      allow_any_instance_of(Gorgon::CallbackHandler).to receive(:before_originate).and_return('job_1')
      expect(Gorgon::OriginatorProtocol).to receive(:new).with(anything, 'job_1')

      @originator.publish
    end

    it "calls after_job_finishes callback" do
      expect_any_instance_of(Gorgon::CallbackHandler).to receive(:after_job_finishes)

      @originator.publish
    end
  end

  describe "#originate" do
    before do
      stub_methods
    end

    it "exits with a non-zero status code when the originator crashes" do
      allow(originator_logger).to receive(:log_error)
      $stderr = StringIO.new # slurp up the error output so we don't pollute the rspec run
      expect_any_instance_of(Gorgon::CallbackHandler).to receive(:before_originate).and_throw("I'm an unhandled exception")

      expect { @originator.originate }.to raise_error(SystemExit) do |error|
        expect(error.success?).to be_falsey
      end
      $stderr = STDERR
    end
  end

  describe "#cancel_job" do
    before do
      stub_methods
    end

    it 'tells ShutdownManager to cancel_job' do
      shutdown_manager = double('ShutdownManager')
      allow(Gorgon::JobState).to receive(:new).and_return job_state

      expect(Gorgon::ShutdownManager).to receive(:new).
          with(hash_including(protocol: protocol, job_state: job_state)).
          and_return(shutdown_manager)
      expect(shutdown_manager).to receive(:cancel_job)

      @originator.publish
      @originator.cancel_job
    end
  end

  describe "#cleanup_if_job_complete" do
    before do
      stub_methods
      allow(Gorgon::JobState).to receive(:new).and_return job_state
      @originator.publish
    end

    it "calls JobState#is_job_complete?" do
      expect(job_state).to receive(:is_job_complete?).and_return false
      @originator.cleanup_if_job_complete
    end

    it "disconnect if job is complete" do
      allow(job_state).to receive(:is_job_complete?).and_return true
      expect(protocol).to receive(:disconnect)
      @originator.cleanup_if_job_complete
    end
  end

  describe "#handle_reply" do
    before do
      stub_methods
      allow(Gorgon::JobState).to receive(:new).and_return job_state
      @originator.publish
    end

    it "returns SPEC_SUCCESS_EXIT_STATUS when payload[:action] is start" do
      allow(job_state).to receive(:file_started)
      expect(@originator.handle_reply(start_payload)).to eq Gorgon::Originator::SPEC_SUCCESS_EXIT_STATUS
    end

    it "returns SPEC_SUCCESS_EXIT_STATUS when payload[:action] is finish" do
      allow(job_state).to receive(:file_finished)
      expect(@originator.handle_reply(finish_payload)).to eq Gorgon::Originator::SPEC_SUCCESS_EXIT_STATUS
    end

    it "returns SPEC_FAILURE_EXIT_STATUS when payload[:action] is crash" do
      allow(job_state).to receive(:gorgon_crash_message)
      expect(@originator.handle_reply(Yajl::Encoder.encode(gorgon_crash_message))).to eq Gorgon::Originator::SPEC_FAILURE_EXIT_STATUS
    end

    it "returns SPEC_FAILURE_EXIT_STATUS when payload[:action] is exception" do
      silence_streams($stdout) do
        expect(@originator.handle_reply(Yajl::Encoder.encode({:type => 'exception'}))).to eq Gorgon::Originator::SPEC_FAILURE_EXIT_STATUS
      end
    end

    it "returns SPEC_FAILURE_EXIT_STATUS when payload[:action] is fail" do
      silence_streams($stdout) do
        expect(@originator.handle_reply(Yajl::Encoder.encode({:type => 'fail'}))).to eq Gorgon::Originator::SPEC_FAILURE_EXIT_STATUS
      end
    end

    it "calls cleanup_if_job_complete" do
      expect(@originator).to receive(:cleanup_if_job_complete)
      @originator.handle_reply finish_payload
    end

    it "calls JobState#file_started if payload[:action] is 'start'" do
      Yajl::Parser.new(:symbolize_keys => true).parse(start_payload)
      expect(job_state).to receive(:file_started)
      @originator.handle_reply(start_payload)
    end

    it "calls JobState#file_finished if payload[:action] is 'finish'" do
      payload = Yajl::Parser.new(:symbolize_keys => true).parse(finish_payload)
      expect(job_state).to receive(:file_finished).with(payload)
      @originator.handle_reply(finish_payload)
    end

    let(:gorgon_crash_message) {{:type => "crash", :hostname => "host",
        :stdout => "some output", :stderr => "some errors"}}

    it "calls JobState#gorgon_crash_message if payload[:type] is 'crash'" do
      expect(job_state).to receive(:gorgon_crash_message).with(gorgon_crash_message)
      @originator.handle_reply(Yajl::Encoder.encode(gorgon_crash_message))
    end
  end

  describe "#handle_new_listener_notification" do
    it "re-publishes the job definition directly to the queue specified by the notification" do
      stub_methods
      @originator.publish

      expect(protocol).to receive(:publish_job_to_one).with(job_definition, 'abcd1234')
      @originator.handle_new_listener_notification({:listener_queue_name => 'abcd1234'}.to_json)
    end
  end

  describe "#job_definition" do
    it "returns a JobDefinition object" do
      allow(@originator).to receive(:configuration).and_return configuration
      job_definition = Gorgon::JobDefinition.new
      expect(Gorgon::JobDefinition).to receive(:new).and_return job_definition
      expect(@originator.job_definition).to equal job_definition
    end

    it "builds anonymous source_tree_path if it was not specified in the configuration" do
      allow(@originator).to receive(:configuration).and_return(configuration.merge(:file_server => {:host => 'host-name'}))
      allow(Socket).to receive(:gethostname).and_return('my-host')
      allow(Dir).to receive(:pwd).and_return('dir')

      expect(@originator.job_definition.sync[:source_tree_path]).to eq("rsync://host-name:43434/src/my-host_dir")
    end

    it "builds ssh source_tree_path if using ssh rsync transport" do
      allow(@originator).to receive(:configuration).and_return(configuration.merge(
        :file_server => {:host => 'host-name'},
        :job => { :sync => { :rsync_transport => 'ssh'}}
      ))
      allow(Socket).to receive(:gethostname).and_return('my-host')
      allow(Dir).to receive(:pwd).and_return('dir')

      expect(@originator.job_definition.sync[:source_tree_path]).to eq("host-name:my-host_dir")
    end
  end

  private

  def stub_methods
    allow(EventMachine).to receive(:run).and_yield
    allow(Gorgon::ProgressBarView).to receive(:new).and_return progress_bar_view
    allow(Gorgon::OriginatorProtocol).to receive(:new).and_return protocol
    allow(@originator).to receive(:configuration).and_return configuration
    allow(@originator).to receive(:connection_information).and_return 'host'
    allow(@originator).to receive(:job_definition).and_return job_definition
  end

  def start_payload
    '{
      "action": "start",
      "hostname": "host",
      "worker_id": "1",
      "filename": "test/file_test.rb"
    }'
  end

  def finish_payload
    '{
      "action": "finish",
      "hostname": "host",
      "worker_id": "1",
      "filename": "test/file_test.rb",
      "failures": [],
      "type": "pass",
      "time": 3
    }'
  end
end
