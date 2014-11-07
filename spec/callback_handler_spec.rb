require 'gorgon'

describe CallbackHandler do

  let(:config) {
    {
      :temp_callbacks => "callback_file.rb",
      :before_start => "some/file.rb",
      :after_complete => "some/other/file.rb",
      :before_creating_workers => "callbacks/before_creating_workers_file.rb",
      :after_sync => "callbacks/after_sync_file.rb",
      :after_creating_workers => "callbacks/after_creating_workers.rb"
    }
  }
  before do
    CallbackHandler.any_instance.stub(:load)
  end

  it "calls before hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:load).with("some/file.rb")

    handler.before_start
  end

  it "does not attempt to load the before start script when before_start is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:load)

    handler.before_start
  end

  it "calls after hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:load).with("some/other/file.rb")

    handler.after_complete
  end

  it "does not attempt to load the after complete script when before_start is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:load)

    handler.after_complete
  end

  it "calls before fork hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:load).with("callbacks/before_creating_workers_file.rb")

    handler.before_creating_workers
  end

  it "does not attempt to load the before creating workers script when before_creating_workers is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:load)

    handler.before_creating_workers
  end

  it "calls after sync hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:load).with("callbacks/after_sync_file.rb")

    handler.after_sync
  end

  it "does not attempt to load the after-sync script when after_sync is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:load)

    handler.after_sync
  end

  it "calls the after creating workers hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:load).with("callbacks/after_creating_workers.rb")

    handler.after_creating_workers
  end

  it "does not attempt to load the after creating workers hook when after_creating_workers is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:load)

    handler.after_creating_workers
  end

  it "loads callback file" do
    CallbackHandler.any_instance.should_receive(:load).with config[:temp_callbacks]

    CallbackHandler.new(config)
  end

  it "does not load callback file if it's not specified" do
    CallbackHandler.any_instance.should_not_receive(:load)

    CallbackHandler.new({})
  end

  context "#before_job_starts" do
    let(:callback_handler) { CallbackHandler.new(config) }

    it "delegates to Gorgon.callbacks.before_job_starts" do
      Gorgon.callbacks.should_receive(:before_job_starts)

      callback_handler.before_job_starts
    end
  end
end
