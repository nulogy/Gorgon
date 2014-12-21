require 'gorgon/runtime_recorder'

describe RuntimeRecorder do

  describe "#record" do
    let (:file_for_recording){ "file_for_recording.rb" }

    it "should not write if no file is given" do
      RuntimeRecorder.stub(:recorded_specs_list_file).and_return("")
      record_values
      file = mock('file')
      File.should_not_receive(:open).with("", "w").and_yield(file)
      file.should_not_receive(:write).with(str_for_recorded_values)
      RuntimeRecorder.write_records_to_file!
      RuntimeRecorder.clear_records!
    end

    it "should write to the given file" do
      RuntimeRecorder.stub(:recorded_specs_list_file).and_return(file_for_recording)
      record_values
      file = mock('file')
      File.should_receive(:open).with(file_for_recording, "w").and_yield(file)
      file.should_receive(:write).with(str_for_recorded_values)
      RuntimeRecorder.write_records_to_file!
      RuntimeRecorder.clear_records!
    end
  end


  describe "#sorted_files" do
    let (:old_files){ [ "old_a.rb", "old_b.rb", "old_c.rb"] }

    before do
      RuntimeRecorder.stub(:recorded_files).and_return old_files
    end

    it "should include new files at the end" do
      current_spec_files = "new_a.rb", "old_b.rb", "old_a.rb", "new_b.rb", "old_c.rb"
      sorted_files = RuntimeRecorder.sorted_files(current_spec_files)
      sorted_files.first(sorted_files.size-2).should == old_files
      sorted_files.last(2).should == ["new_a.rb", "new_b.rb"]
    end

    it "should remove old files that are not in current files" do
      current_spec_files = "new_a.rb", "old_a.rb", "old_c.rb"
      sorted_files = RuntimeRecorder.sorted_files(current_spec_files)
      sorted_files.first(2).should == ["old_a.rb", "old_c.rb"]
      sorted_files.last(1).should == ["new_a.rb"]
    end
  end


  private

  def record_values
    # Record Values
    RuntimeRecorder.clear_records!
    RuntimeRecorder.record!("one.rb", 1.23)
    RuntimeRecorder.record!("zero.rb", 0.23)
    RuntimeRecorder.record!("two.rb", 2.23)
  end

  def str_for_recorded_values
    "two.rb=>2.23\none.rb=>1.23\nzero.rb=>0.23"
  end

end


