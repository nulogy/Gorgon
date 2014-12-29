require 'gorgon/job_state'
require 'gorgon/runtime_recorder'
require 'yajl'

describe RuntimeRecorder do

  let (:runtime_filename){ "runtime_file.json" }

  describe "#initialize" do
    it "adds itself to observers of job_state and sets records as empty" do
      job_state = JobState.new 1
      job_state.should_receive(:add_observer)
      runtime_recorder = RuntimeRecorder.new job_state, runtime_filename
      expect(runtime_recorder.records).to eq({})
    end
  end


  describe "#update" do
    let(:payload){ {filename: "file_spec.rb", runtime: 1.23, action: "finish"} }
    before do
      @job_state = JobState.new 1
      @runtime_recorder = RuntimeRecorder.new @job_state, nil
    end

    it "should record if a file finished" do
      expect(@runtime_recorder.records).to be_empty
      @runtime_recorder.update(payload)
      @runtime_recorder.records = { "file_spec.rb" => 1.23 }
    end

    it "should not record if a file is not finished" do
      expect(@runtime_recorder.records).to be_empty
      @runtime_recorder.update(payload.merge({action:"not_finish"}))
      expect(@runtime_recorder.records).to be_empty
    end

    it "should write to the file if job is completed" do
      @job_state.stub(:is_job_complete?).and_return(true)
      @runtime_recorder.should_receive(:write_records_to_file)
      @runtime_recorder.update(payload)
    end

    it "should not write to the file if job is not completed" do
      @job_state.stub(:is_job_complete?).and_return(false)
      @runtime_recorder.should_not_receive(:write_records_to_file)
      @runtime_recorder.update(payload)
    end
  end


  describe "#write_records_to_file" do
    let(:records){ {"zero.rb" => [:passed,0.23], "one.rb" => [:failed,1.23], "two.rb" => [:passed,2.23]} }

    before do
      @job_state = JobState.new 1
    end

    it "should not write if no file is given" do
      runtime_recorder = RuntimeRecorder.new @job_state, nil
      runtime_recorder.records = records
      file = mock('file')
      File.should_not_receive(:open).and_yield(file)
      file.should_not_receive(:write)
      runtime_recorder.write_records_to_file
    end

    it "should write sorted records to the given file" do
      runtime_recorder = RuntimeRecorder.new @job_state, runtime_filename
      runtime_recorder.records = records
      file = mock('file')
      File.should_receive(:open).with(runtime_filename, 'w').and_yield(file)
      file.should_receive(:write).with("{\n  \"one.rb\": [\n    \"failed\",\n    1.23\n  ],\n  \"two.rb\": [\n    \"passed\",\n    2.23\n  ],\n  \"zero.rb\": [\n    \"passed\",\n    0.23\n  ]\n}")
      runtime_recorder.write_records_to_file
    end
  end

  describe "#sort_records" do

    before do
      @job_state = JobState.new 1
    end

    it "should prioritize failed tests then runtime" do
      records = {
        "zero.rb" => [:passed,0.23],
        "one.rb" => [:failed,1.23],
        "two.rb" => [:passed,2.23],
        "three.rb" => [:failed,3.23],
      }
      sorted_records = {
        "three.rb" => [:failed,3.23],
        "one.rb" => [:failed,1.23],
        "two.rb" => [:passed,2.23],
        "zero.rb" => [:passed,0.23],
      }
      runtime_recorder = RuntimeRecorder.new(@job_state, runtime_filename)
      runtime_recorder.records = records
      runtime_recorder.send(:sort_records)
      expect(runtime_recorder.records).to eq(sorted_records)
    end

  end

end

