require 'gorgon/worker_manager'

describe WorkerManager do
  let(:exchange) { stub("Bunny Exchange", :publish => nil) }
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil, :delete => nil,
                     :pop => {:payload => :queue_empty}) }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange,
                     :queue => queue, :stop => nil) }
  before do
    STDIN.stub!(:read).and_return "{}"
    STDOUT.stub!(:reopen)
    STDERR.stub!(:reopen)
    Bunny.stub!(:new).and_return(bunny)
    Configuration.stub!(:load_configuration_from_file).and_return({})
    EventMachine.stub!(:run).and_yield
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      STDIN.should_receive(:read).and_return '{"source_tree_path":"path/to/source",
             "sync_exclude":["log"]}'

      Configuration.should_receive(:load_configuration_from_file).with("file.json").and_return({})

      WorkerManager.build "file.json"
    end

    it "redirect output to a file since writing to a pipe may block when pipe is full" do
      File.should_receive(:open).with(WorkerManager::STDOUT_FILE, 'w').and_return(:file1)
      STDOUT.should_receive(:reopen).with(:file1)
      File.should_receive(:open).with(WorkerManager::STDERR_FILE, 'w').and_return(:file2)
      STDERR.should_receive(:reopen).with(:file2)
      WorkerManager.build "file.json"
    end
  end
end
