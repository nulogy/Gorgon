require "gorgon/runner_transcript"

describe RunnerTranscript do
  let(:fd) {double("File descriptor", :write => nil)}

  it "responds to finish actions" do
    publisher = double()
    publisher.should_receive(:add_observer)

    RunnerTranscript.new({}, publisher)
  end

  context "writing the transcript" do
    it "writes the output file when the job is completed" do
      subject = RunnerTranscript.new({}, double(add_observer: nil, is_job_complete?: true, is_job_cancelled?: false))
      expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb"]})

      File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
      fd.should_receive(:write).with(expected_output)

      subject.update(finish_payload)
    end

    it "writes the output file when the job is cancelled" do
      subject = RunnerTranscript.new({}, double(add_observer: nil, is_job_cancelled?: true, is_job_complete?: false))
      expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb"]})
      File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
      fd.should_receive(:write).with(expected_output)

      subject.update(finish_payload)
    end

    it "preserves the order in which files are reported to have finished", focus: true do
      publisher = double(add_observer: nil, is_job_cancelled?: false)
      publisher.should_receive(:is_job_complete?).and_return(false, true)
      subject = RunnerTranscript.new({}, publisher)
      expected_output = Yajl::Encoder.encode({"1" => ["test/file_test.rb", "test/second_test.rb"]})
      File.should_receive(:open).with(RunnerTranscript::DEFAULT_OUTPUT_FILE, 'w+').and_yield fd
      fd.should_receive(:write).with(expected_output)

      puts '====='
      subject.update(finish_payload)
      subject.update(second_finish_payload)
      puts '====='
    end

    it "does not write the output file otherwise" do
      subject = RunnerTranscript.new({}, double(add_observer: nil, is_job_cancelled?: false, is_job_complete?: false))
      File.should_not_receive(:open)
      fd.should_not_receive(:write)

      subject.update(finish_payload)
    end
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

def second_finish_payload
  {
    action: "finish",
    hostname: "host",
    worker_id: "1",
    filename: "test/second_test.rb",
    failures: [],
    type: "pass",
    time: 3
  }
end
