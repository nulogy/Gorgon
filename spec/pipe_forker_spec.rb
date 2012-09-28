require 'gorgon/pipe_forker'

describe PipeForker do
  let(:io_pipe) { stub("IO object", :close => nil)}
  let(:pipe) {stub("Pipe", :write => io_pipe)}

  let(:container_class) do
    Class.new do
      extend(PipeForker)
    end
  end

  before do
    IO.stub!(:pipe).and_return([io_pipe, io_pipe])
    STDIN.stub!(:reopen)
    container_class.stub!(:fork).and_yield.and_return(1)
    container_class.stub!(:exit)
  end

  describe ".pipe_fork" do
    it "creates a new pipe" do
      IO.should_receive(:pipe).once.and_return ([io_pipe,io_pipe])
      container_class.pipe_fork { }
    end

    it "forks once" do
      container_class.should_receive(:fork).and_yield
      container_class.pipe_fork { }
    end

    it "closes both side of pipe inside child and read in parent" do
      io_pipe.should_receive(:close).exactly(3).times
      container_class.pipe_fork { }
    end

    it "reopens stdin with a pipe" do
      STDIN.should_receive(:reopen).with(io_pipe)
      container_class.pipe_fork { }
    end

    it "yields" do
      has_yielded = false
      container_class.pipe_fork { has_yielded = true }
      has_yielded.should be_true
    end

    it "returns pid of new process and a pipe" do
      pid, stdin = container_class.pipe_fork { }
      pid.should be 1
      stdin.should == io_pipe
    end
  end
end
