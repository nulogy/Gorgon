require 'gorgon/callback_handler'

describe CallbackHandler do

  let(:config) {
    {
      :before_start => "some/file.sh",
      :after_complete => "some/other/file.sh"
    }
  }

  it "calls before hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:system).with("some/file.sh")

    handler.before_start
  end

  it "does not attempt to shell out to the before start script when before_start is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:system)

    handler.before_start
  end

  it "calls after hook" do
    handler = CallbackHandler.new(config)

    handler.should_receive(:system).with("some/other/file.sh")

    handler.after_complete
  end

  it "does not attempt to shell out to the after complete script when before_start is not defined" do
    handler = CallbackHandler.new({})

    handler.should_not_receive(:system)

    handler.after_complete
  end
end