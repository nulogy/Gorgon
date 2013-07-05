require 'gorgon/source_tree_syncer'

describe SourceTreeSyncer.new("") do
  it { should respond_to :exclude= }
  it { should respond_to :sync }
  it { should respond_to :sys_command }
  it { should respond_to :remove_temp_dir }
  it { should respond_to :success? }
  it { should respond_to :output }
  it { should respond_to :errors }

  let(:stdin) { stub("IO object", :close => nil)}
  let(:stdout) { stub("IO object", :read => nil, :close => nil)}
  let(:stderr) { stub("IO object", :read => nil, :close => nil)}
  let(:status) { stub("Process Status", :exitstatus => 0)}

  before do
    @syncer = SourceTreeSyncer.new "path/to/source"
    stub_utilities_methods
  end

  describe "#sync" do
    it "makes tempdir and changes current dir to temdir" do
      Dir.should_receive(:mktmpdir).and_return("tmp/dir")
      Dir.should_receive(:chdir).with("tmp/dir")
      @syncer.sync
    end

    context "invalid source_tree_path" do
      it "gives error if source_tree_path is empty string" do
        syncer = SourceTreeSyncer.new "  "
        Dir.should_not_receive(:mktmpdir)
        syncer.sync
        syncer.success?.should be_false
        syncer.errors.should == "Source tree path cannot be empty. Check your gorgon.json file."
      end

      it "gives error if source_tree_path is nil" do
        syncer = SourceTreeSyncer.new nil
        Dir.should_not_receive(:mktmpdir)
        syncer.sync
        syncer.success?.should be_false
        syncer.errors.should == "Source tree path cannot be nil. Check your gorgon.json file."
      end
    end

    context "options" do
      it "runs rsync system command with appropriate options" do
        cmd = /rsync.*-azr .*path\/to\/source\/\ \./
        Open4.should_receive(:popen4).with(cmd)
        @syncer.sync
      end

      it "exclude files when they are specified" do
        @syncer.exclude = ["log", ".git"]
        Open4.should_receive(:popen4).with(/--exclude log --exclude .git/)
        @syncer.sync
      end

      it "uses io timeout to avoid listener hanging forever in case rsync asks for any input" do
        opt = /--timeout=5/
        Open4.should_receive(:popen4).with(opt)
        @syncer.sync
      end
    end
  end

  describe "#success?" do
    it "returns true if sync execution was successful" do
      status.should_receive(:exitstatus).and_return(0)
      @syncer.sync
      @syncer.success?.should be_true
    end

    it "returns false if sync execution failed" do
      status.should_receive(:exitstatus).and_return(1)
      @syncer.sync
      @syncer.success?.should be_false
    end
  end

  describe "#output" do
    it "returns standard output of rsync" do
      stdout.should_receive(:read).and_return("some output")
      @syncer.sync
      @syncer.output.should == "some output"
    end
  end

  describe "#errors" do
    it "returns standard error output of rsync" do
      stderr.should_receive(:read).and_return("some errors")
      @syncer.sync
      @syncer.errors.should == "some errors"
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
    Open4.stub!(:popen4).and_return([1, stdin, stdout, stderr])
    Process.stub!(:waitpid2).and_return([nil, status])
    FileUtils.stub!(:remove_entry_secure)
    @syncer.stub!(:system)
  end
end
