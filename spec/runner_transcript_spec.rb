require "gorgon/runner_transcript"

describe RunnerTranscript do
  let(:fd) {double("File descriptor", :write => nil)}

  it "writes the output file when the job is completed" do
    subject = RunnerTranscript.new({}, double(is_job_complete?: true, is_job_cancelled?: false))
    expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb"]})

    File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
    fd.should_receive(:write).with(expected_output)

    subject.update(finish_payload)
  end

  it "writes the output file when the job is cancelled" do
    subject = RunnerTranscript.new({}, double(is_job_cancelled?: true, is_job_complete?: false))
    expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb"]})
    File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
    fd.should_receive(:write).with(expected_output)

    subject.update(finish_payload)
  end
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
