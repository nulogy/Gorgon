require "gorgon/runner_transcript"

describe RunnerTranscript do
  let(:job_state) { double("Job State", :add_observer => nil,
                         :is_job_complete? => true, :is_job_cancelled? => false,
                         :each_failed_test => nil,
                         :each_running_file => nil)}
  let(:fd) {double("File descriptor", :write => nil)}

  subject do
    RunnerTranscript.new({}, job_state)
  end

  it { should respond_to :update }

  it "writes the output file when the job is completed" do
    expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb"]})
    File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
    fd.should_receive(:write).with(expected_output)

    subject.update(finish_payload)
  end
  xit "writes the output file when the job is cancelled"
end

def finish_payload
  {
    action: "finish",
    hostname: "host",
    worker_id: "1",
    filename: "test/file_test.rb",
    failures: [],
    type: "pass",
    time: 3
  }
end


