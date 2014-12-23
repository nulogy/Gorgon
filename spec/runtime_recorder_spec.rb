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
      runtime_recorder.records.should == {}
    end
  end


  describe "#update" do
    let(:payload){ {filename: "file_spec.rb", runtime: 1.23, action: "finish"} }
    before do
      @job_state = JobState.new 1
      @runtime_recorder = RuntimeRecorder.new @job_state, nil
    end

    it "should record if a file finished" do
      @runtime_recorder.records.empty?.should == true
      @runtime_recorder.update(payload)
      @runtime_recorder.records = { "file_spec.rb" => 1.23 }
    end

    it "should not record if a file is not finished" do
      @runtime_recorder.records.empty?.should == true
      @runtime_recorder.update(payload.merge({action:"not_finish"}))
      @runtime_recorder.records.empty?.should == true
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
    let(:sample_records){ {"zero.rb" => 0.23, "one.rb" => 1.23, "two.rb" => 2.23} }

    before do
      @job_state = JobState.new 1
    end

    it "should not write if no file is given" do
      runtime_recorder = RuntimeRecorder.new @job_state, nil
      runtime_recorder.records = sample_records
      file = mock('file')
      File.should_not_receive(:open).and_yield(file)
      file.should_not_receive(:write)
      runtime_recorder.write_records_to_file
    end

    it "should write sorted records to the given file" do
      runtime_recorder = RuntimeRecorder.new @job_state, runtime_filename
      runtime_recorder.records = sample_records
      file = mock('file')
      File.should_receive(:open).with(runtime_filename, 'w').and_yield(file)
      file.should_receive(:write).with("{\n  \"two.rb\": 2.23,\n  \"one.rb\": 1.23,\n  \"zero.rb\": 0.23\n}")
      runtime_recorder.write_records_to_file
    end
  end


  #describe "#sorted_files" do
    #let (:old_files){ [ "old_a.rb", "old_b.rb", "old_c.rb"] }

    #before do
      #RuntimeRecorder.stub(:recorded_files).and_return old_files
    #end

    #it "should include new files at the end" do
      #current_spec_files = "new_a.rb", "old_b.rb", "old_a.rb", "new_b.rb", "old_c.rb"
      #sorted_files = RuntimeRecorder.sorted_files(current_spec_files)
      #sorted_files.first(sorted_files.size-2).should == old_files
      #sorted_files.last(2).should == ["new_a.rb", "new_b.rb"]
    #end

    #it "should remove old files that are not in current files" do
      #current_spec_files = "new_a.rb", "old_a.rb", "old_c.rb"
      #sorted_files = RuntimeRecorder.sorted_files(current_spec_files)
      #sorted_files.first(2).should == ["old_a.rb", "old_c.rb"]
      #sorted_files.last(1).should == ["new_a.rb"]
    #end
  #end

end

