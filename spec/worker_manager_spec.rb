require 'gorgon/worker_manager'

describe Gorgon::WorkerManager do
  let(:exchange) { double("GorgonBunny Exchange", :publish => nil) }
  let(:queue) { double("Queue", :bind => nil, :subscribe => nil, :delete => nil,
                     :pop => {:payload => :queue_empty}) }
  let(:bunny) { double("GorgonBunny", :start => nil, :exchange => exchange,
                     :queue => queue, :stop => nil) }
  before do
    allow(STDIN).to receive(:read).and_return "{}"
    allow(STDOUT).to receive(:reopen)
    allow(STDERR).to receive(:reopen)
    allow(STDOUT).to receive(:sync)
    allow(STDERR).to receive(:sync)
    allow(GorgonBunny).to receive(:new).and_return(bunny)
    allow(Gorgon::Configuration).to receive(:load_configuration_from_file).and_return({})
    allow(EventMachine).to receive(:run).and_yield
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      expect(STDIN).to receive(:read).and_return '{"source_tree_path":"path/to/source",
             "sync":{"exclude":["log"]}}'

      expect(Gorgon::Configuration).to receive(:load_configuration_from_file).with("file.json").and_return({})

      Gorgon::WorkerManager.build "file.json"
    end

    it "redirect output to a file since writing to a pipe may block when pipe is full" do
      expect(File).to receive(:open).with(Gorgon::WorkerManager::STDOUT_FILE, 'w').and_return(:file1)
      expect(STDOUT).to receive(:reopen).with(:file1)
      expect(File).to receive(:open).with(Gorgon::WorkerManager::STDERR_FILE, 'w').and_return(:file2)
      expect(STDERR).to receive(:reopen).with(:file2)
      Gorgon::WorkerManager.build ""
    end

    it "use STDOUT#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      expect(STDOUT).to receive(:reopen).once.ordered
      expect(STDOUT).to receive(:sync=).with(true).once.ordered
      Gorgon::WorkerManager.build ""
    end

    it "use STDERR#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      expect(STDERR).to receive(:reopen).once.ordered
      expect(STDERR).to receive(:sync=).with(true).once.ordered
      Gorgon::WorkerManager.build ""
    end
  end
end
