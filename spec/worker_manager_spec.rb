require 'gorgon/worker_manager'

describe WorkerManager do
  let(:exchange) { stub("Bunny Exchange") }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange) }

  before do
    Bunny.stub(:new).and_return(bunny)
    STDIN.should_receive(:read).and_return '{"source_tree_path":"."}'
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      Configuration.stub!(:load_configuration_from_file).and_return({})
      Configuration.should_receive(:load_configuration_from_file).with("file.json")

      WorkerManager.build "file.json"
    end
  end
end
