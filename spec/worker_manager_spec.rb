require 'gorgon/worker_manager'

describe WorkerManager do
  let(:exchange) { stub("Bunny Exchange") }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange) }

  before do
    Bunny.stub(:new).and_return(bunny)
  end

  describe ".build" do
    it "should load_configuration_from_file" do
      Configuration.stub!(:load_configuration_from_file).and_return({})
      $stdin.stub!(:read).and_return '{}'
      Configuration.should_receive(:load_configuration_from_file).with("file.json")

      WorkerManager.build "file.json"
    end
  end

  describe "#manage" do
    
  end
end
