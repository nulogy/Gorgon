require 'gorgon/pipe_forker'

describe Gorgon::PipeForker do
  let(:io_pipe) { double("IO object", :close => nil)}
  let(:pipe) {double("Pipe", :write => io_pipe)}

  let(:container_class) do
    Class.new do
      extend(Gorgon::PipeForker)
    end
  end

  before do
    allow(IO).to receive(:pipe).and_return([io_pipe, io_pipe])
    allow(STDIN).to receive(:reopen)
    allow(container_class).to receive(:fork).and_yield.and_return(1)
    allow(container_class).to receive(:exit)
  end

  describe ".pipe_fork" do
    it "creates a new pipe" do
      expect(IO).to receive(:pipe).once.and_return ([io_pipe,io_pipe])
      container_class.pipe_fork { }
    end

    it "forks once" do
      expect(container_class).to receive(:fork).and_yield
      container_class.pipe_fork { }
    end

    it "closes both side of pipe inside child and read in parent" do
      expect(io_pipe).to receive(:close).exactly(3).times
      container_class.pipe_fork { }
    end

    it "reopens stdin with a pipe" do
      expect(STDIN).to receive(:reopen).with(io_pipe)
      container_class.pipe_fork { }
    end

    it "yields" do
      has_yielded = false
      container_class.pipe_fork { has_yielded = true }
      expect(has_yielded).to be_truthy
    end

    it "returns pid of new process and a pipe" do
      pid, stdin = container_class.pipe_fork { }
      expect(pid).to eq(1)
      expect(stdin).to eq(io_pipe)
    end
  end
end
