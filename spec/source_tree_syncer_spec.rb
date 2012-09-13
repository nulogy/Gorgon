require 'gorgon/source_tree_syncer'

describe SourceTreeSyncer.new("") do
  it { should respond_to :exclude= }
  it { should respond_to :sync }
  it { should respond_to :sys_command }
  it { should respond_to :remove_temp_dir }

  describe "#sync" do
    before do
      @syncer = SourceTreeSyncer.new "path/to/source"
      stub_utilities_methods
    end

    it "makes tempdir and changes current dir to temdir" do
      Dir.should_receive(:mktmpdir).and_return("tmp/dir")
      Dir.should_receive(:chdir).with("tmp/dir")
      @syncer.sync
    end

    it "runs rsync system command with appropriate options" do
      cmd = "rsync -az -r --rsh=ssh path/to/source/* ."
      @syncer.should_receive(:system).with(cmd)
      @syncer.sync
    end

    it "returns true if sys command execution was successful" do
      $?.stub!(:exitstatus).and_return 0
      @syncer.sync.should be_true
    end

    it "returns false if sys command execution failed" do
      $?.stub!(:exitstatus).and_return 1
      @syncer.sync.should be_false
    end
  end

  describe "#remove_temp_dir" do
    before do
      @syncer = SourceTreeSyncer.new "path/to/source"
      stub_utilities_methods
      @syncer.sync
    end

    it "remove temporary dir" do
      FileUtils.should_receive(:remove_entry_secure).with("tmp/dir")
      @syncer.remove_temp_dir
    end
  end

  private

  def stub_utilities_methods
    Dir.stub!(:mktmpdir).and_return("tmp/dir")
    Dir.stub!(:chdir)
    FileUtils.stub!(:remove_entry_secure)
    @syncer.stub!(:system)
  end
end
