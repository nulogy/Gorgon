require 'gorgon/job_state'
require 'gorgon/runtime_recorder'
require 'yajl'

describe Gorgon::RuntimeRecorder do

  let (:runtime_filename){ "runtime_file.json" }

  describe "#initialize" do
    it "adds itself to observers of job_state and sets records as empty" do
      job_state = Gorgon::JobState.new 1
      expect(job_state).to receive(:add_observer)
      runtime_recorder = Gorgon::RuntimeRecorder.new job_state, runtime_filename
      expect(runtime_recorder.records).to eq({})
    end
  end


  describe "#update" do
    let(:payload){ {filename: "file_spec.rb", runtime: 1.23, action: "finish"} }
    before do
      @job_state = Gorgon::JobState.new 1
      @runtime_recorder = Gorgon::RuntimeRecorder.new @job_state, nil
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
      allow(@job_state).to receive(:is_job_complete?).and_return(true)
      expect(@runtime_recorder).to receive(:write_records_to_file)
      @runtime_recorder.update(payload)
    end

    it "should not write to the file if job is not completed" do
      allow(@job_state).to receive(:is_job_complete?).and_return(false)
      expect(@runtime_recorder).not_to receive(:write_records_to_file)
      @runtime_recorder.update(payload)
    end
  end


  describe "#write_records_to_file" do
    let(:sample_records){ {"zero.rb" => 0.23, "one.rb" => 1.23, "two.rb" => 2.23} }

    before do
      @job_state = Gorgon::JobState.new 1
    end

    it "should not write if no file is given" do
      runtime_recorder = Gorgon::RuntimeRecorder.new @job_state, nil
      runtime_recorder.records = sample_records
      file = double('file')
      expect(File).not_to receive(:open).and_yield(file)
      expect(file).not_to receive(:write)
      runtime_recorder.write_records_to_file
    end

    it "should write sorted records to the given file" do
      runtime_recorder = Gorgon::RuntimeRecorder.new @job_state, runtime_filename
      runtime_recorder.records = sample_records
      file = double('file')
      expect(File).to receive(:open).with(runtime_filename, 'w').and_yield(file)
      expect(file).to receive(:write).with("{\n  \"two.rb\": 2.23,\n  \"one.rb\": 1.23,\n  \"zero.rb\": 0.23\n}")
      runtime_recorder.write_records_to_file
    end
  end

end

