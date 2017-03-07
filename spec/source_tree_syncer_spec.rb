require 'gorgon/source_tree_syncer'

describe Gorgon::SourceTreeSyncer.new(source_tree_path: "") do
  it { should respond_to :pull }
  it { should respond_to :push }

  let(:stdin) { double("IO object", :close => nil)}
  let(:stdout) { double("IO object", :read => nil, :close => nil)}
  let(:stderr) { double("IO object", :read => nil, :close => nil)}
  let(:status) { double("Process Status", :exitstatus => 0)}

  before do
    @syncer = Gorgon::SourceTreeSyncer.new(source_tree_path: "path/to/source")
    stub_utilities_methods
  end

  shared_examples_for "options" do
    describe "options" do
      it "exclude files when they are specified" do
        @syncer = Gorgon::SourceTreeSyncer.new(source_tree_path: "path/to/source", exclude: ["log", ".git"])
        Open4.should_receive(:popen4).with(/--exclude log --exclude .git/)
        @syncer.public_send(operation)
      end

      it "uses io timeout to avoid listener hanging forever in case rsync asks for any input" do
        opt = /--timeout=5/
        Open4.should_receive(:popen4).with(opt)
        @syncer.public_send(operation)
      end
    end
  end

  describe "#pull" do
    it "makes tempdir and changes current dir to temdir" do
      Dir.should_receive(:mktmpdir).and_return("tmp/dir")
      Dir.should_receive(:chdir).with("tmp/dir")
      execution_context = @syncer.pull do |context|
        expect(context.success).to be_true, "Syncer error: #{context.errors}"
      end
      expect(execution_context.success).to be_true, "Syncer error: #{execution_context.errors}"
    end

    context "invalid source_tree_path" do
      it "gives error if source_tree_path is empty string" do
        syncer = Gorgon::SourceTreeSyncer.new(source_tree_path: "  ")
        Dir.should_not_receive(:mktmpdir)
        execution_context = syncer.pull do |context|
          context.success.should be_false
          context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
        end

        execution_context.success.should be_false
        execution_context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
      end

      it "gives error if source_tree_path is nil" do
        syncer = Gorgon::SourceTreeSyncer.new(nil)
        Dir.should_not_receive(:mktmpdir)
        execution_context = syncer.pull do |context|
          context.success.should be_false
          context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
        end
        execution_context.success.should be_false
        execution_context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
      end
    end

    context "options" do
      it_should_behave_like "options" do
        let(:operation) { :pull }
      end

      it "runs rsync system command with appropriate options" do
        cmd = /rsync.*-azr .*path\/to\/source\/\ \./
        Open4.should_receive(:popen4).with(cmd)
        @syncer.pull
      end
    end
  end

  describe '#push' do
    context "source tree path" do
      it "is empty string" do
        syncer = Gorgon::SourceTreeSyncer.new(source_tree_path: "  ")
        execution_context = syncer.push

        execution_context.success.should be_false
        execution_context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
      end

      it "is nil" do
        syncer = Gorgon::SourceTreeSyncer.new(nil)
        execution_context = syncer.push

        execution_context.success.should be_false
        execution_context.errors.should == "Source tree path cannot be blank. Check your gorgon.json file."
      end

      it "is valid" do
        execution_context = @syncer.push
        execution_context.success.should be_true
      end
    end

    context "command execution" do
      it "returns true if sync execution was successful" do
        status.should_receive(:exitstatus).and_return(0)
        execution_context = @syncer.push
        execution_context.success.should be_true
      end

      it "returns false if sync execution failed" do
        status.should_receive(:exitstatus).and_return(1)
        execution_context = @syncer.push
        execution_context.success.should be_false
      end

      it "returns standard output of rsync" do
        stdout.should_receive(:read).and_return("some output")
        execution_context = @syncer.push
        execution_context.output.should == "some output"
      end

      it "returns standard error output of rsync" do
        stderr.should_receive(:read).and_return("some errors")
        execution_context = @syncer.push
        execution_context.errors.should == "some errors"
      end
    end

    context "options" do
      it_should_behave_like "options" do
        let(:operation) { :push }
      end

      it "runs rsync system command with appropriate options" do
        cmd = /rsync.*-azr .* \. path\/to\/source/
        Open4.should_receive(:popen4).with(cmd)
        @syncer.push
      end
    end
  end

  describe "command execution" do
    it "returns true if sync execution was successful" do
      status.should_receive(:exitstatus).and_return(0)
      execution_context = @syncer.pull do |context|
        context.success.should be_true
      end
      execution_context.success.should be_true
    end

    it "returns false if sync execution failed" do
      status.should_receive(:exitstatus).and_return(1)
      execution_context = @syncer.pull do |context|
        context.success.should be_false
      end
      execution_context.success.should be_false
    end

    it "returns standard output of rsync" do
      stdout.should_receive(:read).and_return("some output")
      execution_context = @syncer.pull do |context|
        context.output.should == "some output"
      end
      execution_context.output.should == "some output"
    end

    it "returns standard error output of rsync" do
      stderr.should_receive(:read).and_return("some errors")
      execution_context = @syncer.pull do |context|
        context.errors.should == "some errors"
      end
      execution_context.errors.should == "some errors"
    end
  end

  describe "clean up" do
    before do
      @syncer = Gorgon::SourceTreeSyncer.new(source_tree_path: "path/to/source")
      stub_utilities_methods
    end

    it "remove temporary dir" do
      FileUtils.should_receive(:remove_entry_secure).with("tmp/dir")
      @syncer.pull
    end

    it "removes temporary dir in case of exception" do
      FileUtils.should_receive(:remove_entry_secure).with("tmp/dir")
      begin
      @syncer.pull do |context|
        raise
      end
      rescue
      end
    end
  end

  private

  def stub_utilities_methods
    Dir.stub(:mktmpdir).and_return("tmp/dir")
    Dir.stub(:chdir)
    Open4.stub(:popen4).and_return([1, stdin, stdout, stderr])
    Process.stub(:waitpid2).and_return([nil, status])
    FileUtils.stub(:remove_entry_secure)
  end
end
