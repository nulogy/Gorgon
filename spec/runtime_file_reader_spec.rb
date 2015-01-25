require 'gorgon/runtime_file_reader'
require 'yajl'

describe RuntimeFileReader do

  let(:old_files){ ["old_a.rb", "old_b.rb", "old_c.rb"] }

  describe "#old_files" do
    let(:configuration){ {runtime_filename: "runtime_file.json"} }

    it "should read runtime_file" do
      File.stub(:file?).and_return(true)
      runtime_file_reader = RuntimeFileReader.new(configuration)
      File.should_receive(:open).with(configuration[:runtime_filename], 'r')
      runtime_file_reader.old_files
    end

    it "should return empty array if runtime_file is invalid" do
      File.should_receive(:file?).and_return(false)
      runtime_file_reader = RuntimeFileReader.new(configuration)
      File.should_not_receive(:open)
      runtime_file_reader.old_files
    end
  end


  describe "#sorted_files_by_runtime" do
    let(:configuration){ {runtime_filename: "runtime_file.json"} }

    before do
      @runtime_file_reader = RuntimeFileReader.new(configuration)
      @runtime_file_reader.stub(:old_files).and_return old_files
    end

    it "should include new files at the end" do
      current_spec_files = ["new_a.rb", "old_b.rb", "old_a.rb", "new_b.rb", "old_c.rb"]
      sorted_files_by_runtime = @runtime_file_reader.send(:sorted_files_by_runtime, current_spec_files)
      expect(sorted_files_by_runtime.first(sorted_files_by_runtime.size-2)).to eq(old_files)
      expect(sorted_files_by_runtime.last(2)).to eq(["new_a.rb", "new_b.rb"])
    end

    it "should remove old files that are not in current files" do
      current_spec_files = ["new_a.rb", "old_a.rb", "old_c.rb"]
      sorted_files_by_runtime = @runtime_file_reader.send(:sorted_files_by_runtime, current_spec_files)
      expect(sorted_files_by_runtime.first(2)).to eq(["old_a.rb", "old_c.rb"])
      expect(sorted_files_by_runtime.last(1)).to eq(["new_a.rb"])
    end
  end


  describe "#sorted_files" do
    let(:configuration){ {files: ["glob_1", "glob_2", "glob_3"]} }

    before do
      @runtime_file_reader = RuntimeFileReader.new(configuration)
      @runtime_file_reader.stub(:old_files).and_return old_files
    end

    it "sort by globs then by runtime" do
      globs = {
        "glob_1" => ["old_b.rb"],
        "glob_2" => ["new_c.rb", "old_a.rb"],
        "glob_3" => ["new_a.rb", "new_b.rb", "new_c.rb", "old_a.rb", "old_b.rb"]
      }
      Dir.stub(:[]) do |glob|
        globs[glob]
      end
      sorted_files = @runtime_file_reader.sorted_files
      expect(sorted_files).to eq(
        ["old_b.rb", "old_a.rb", "new_c.rb", "new_a.rb", "new_b.rb"]
      )
    end
  end


end

