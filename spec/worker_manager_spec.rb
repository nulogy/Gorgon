require 'gorgon/worker_manager'

describe Gorgon::WorkerManager do
  let(:exchange) { double("GorgonBunny Exchange", :publish => nil) }
  let(:queue) { double("Queue", :bind => nil, :subscribe => nil, :delete => nil,
                     :pop => {:payload => :queue_empty}) }
  let(:bunny) { double("GorgonBunny", :start => nil, :exchange => exchange,
                     :queue => queue, :stop => nil) }
  before do
    STDIN.stub(:read).and_return "{}"
    STDOUT.stub(:reopen)
    STDERR.stub(:reopen)
    STDOUT.stub(:sync)
    STDERR.stub(:sync)
    GorgonBunny.stub(:new).and_return(bunny)
    Gorgon::Configuration.stub(:load_configuration_from_file).and_return({})
    EventMachine.stub(:run).and_yield
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      STDIN.should_receive(:read).and_return '{"source_tree_path":"path/to/source",
             "sync":{"exclude":["log"]}}'

      Gorgon::Configuration.should_receive(:load_configuration_from_file).with("file.json").and_return({})

      Gorgon::WorkerManager.build "file.json"
    end

    it "redirect output to a file since writing to a pipe may block when pipe is full" do
      File.should_receive(:open).with(Gorgon::WorkerManager::STDOUT_FILE, 'w').and_return(:file1)
      STDOUT.should_receive(:reopen).with(:file1)
      File.should_receive(:open).with(Gorgon::WorkerManager::STDERR_FILE, 'w').and_return(:file2)
      STDERR.should_receive(:reopen).with(:file2)
      Gorgon::WorkerManager.build ""
    end

    it "use STDOUT#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      STDOUT.should_receive(:reopen).once.ordered
      STDOUT.should_receive(:sync=).with(true).once.ordered
      Gorgon::WorkerManager.build ""
    end

    it "use STDERR#sync to flush output immediately so if an exception happens, we can grab the last\
few lines of output and send it to originator. Order matters" do
      STDERR.should_receive(:reopen).once.ordered
      STDERR.should_receive(:sync=).with(true).once.ordered
      Gorgon::WorkerManager.build ""
    end
  end
end
