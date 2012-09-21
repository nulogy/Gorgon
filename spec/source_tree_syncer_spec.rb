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

    context "options" do
      it "runs rsync system command with appropriate options" do
        cmd = /rsync.*-azr .*path\/to\/source\/\ \./
        @syncer.should_receive(:system).with(cmd)
        @syncer.sync
      end

      it "exclude files when they are specified" do
        @syncer.exclude = ["log", ".git"]
        @syncer.should_receive(:system).with(/--exclude log --exclude .git/)
        @syncer.sync
      end

      it "use NumberOfPasswordPrompts 0 as ssh option to avoid password prompts that will hang the listener" do
        opt = /--rsh='ssh .*-o NumberOfPasswordPrompts=0.*'/
        @syncer.should_receive(:system).with(opt)
        @syncer.sync
      end

      it "set UserKnownHostsFile to /dev/null so we avoid hosts id changes and eavesdropping warnings in futures connections" do
        opt = /ssh .*-o UserKnownHostsFile=\/dev\/null/
        @syncer.should_receive(:system).with(opt)
        @syncer.sync
      end

      it "set StrictHostKeyChecking to 'no' to avoid confirmation prompt of connection to unkown host" do
        opt = /ssh .*-o StrictHostKeyChecking=no/
        @syncer.should_receive(:system).with(opt)
        @syncer.sync
      end

      it "uses io timeout to avoid listener hanging forever in case rsync asks for any input" do
        opt = /--timeout=5/
        @syncer.should_receive(:system).with(opt)
        @syncer.sync
      end
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
