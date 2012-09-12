require 'gorgon/worker_manager'

describe WorkerManager do
  let(:exchange) { stub("Bunny Exchange", :publish => nil) }
  let(:queue) { stub("Queue", :bind => nil, :subscribe => nil) }
  let(:bunny) { stub("Bunny", :start => nil, :exchange => exchange,
                     :queue => queue) }
  let(:syncer) { stub("SourceTreeSyncer", :sync => nil, :exclude= => nil, :remove_temp_dir => nil,
                      :sys_command => "rsync ...")}

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

  describe "#manage" do
    before do
      Configuration.stub!(:load_configuration_from_file).and_return({:worker_slots => 3})
      @manager = WorkerManager.build "file.json"
    end

    it "copy source tree" do
      SourceTreeSyncer.should_receive(:new).with("path/to/source").and_return syncer
      syncer.should_receive(:exclude=).with(["log"])
      syncer.should_receive(:sync)
      @manager.manage
    end

    it "remove temp source directory when complet" do
      SourceTreeSyncer.stub!(:new).and_return syncer
      syncer.should_receive(:remove_temp_dir)
      @manager.manage
    end
  end

  after :all do
    system("rm *.pipe")
  end
end
