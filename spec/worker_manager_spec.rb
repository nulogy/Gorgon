require 'gorgon/worker_manager'

describe WorkerManager do
  let(:exchange) { stub("Bunny Exchange", :publish => nil) }
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil, :delete => nil,
                     :pop => {:payload => :queue_empty}) }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange,
                     :queue => queue, :stop => nil) }
  before do
    Bunny.stub(:new).and_return(bunny)
    STDIN.should_receive(:read).and_return '{"source_tree_path":"path/to/source",
             "sync_exclude":["log"]}'
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      Configuration.stub!(:load_configuration_from_file).and_return({})
      Configuration.should_receive(:load_configuration_from_file).with("file.json")

      WorkerManager.build "file.json"
    end
  end
end
