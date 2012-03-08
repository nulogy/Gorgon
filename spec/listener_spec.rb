require 'gorgon/listener'

describe Listener do
  describe "logging to a file" do
    before do
      @stub_logger = stub :info => true
      Logger.stub(:new).and_return(@stub_logger)
    end

    context "passing a log file path in the configuration" do
      before do
        Listener.any_instance.stub(:configuration).and_return({:log_file => 'listener.log'})
      end

      it "should use 'log_file' from the configuration as the log file" do
        Logger.should_receive(:new).with('listener.log')
        Listener.new
      end

      it "should log to 'log_file'" do
        @stub_logger.should_receive(:info).with("Listener initialized")

        Listener.new
      end

    end

    context "without specifying a log file path" do
      before do
        Listener.any_instance.stub(:configuration).and_return({ })

      end

      it "should not log" do
        Logger.should_not_receive(:new)
        @stub_logger.should_not_receive(:info)

        Listener.new
      end
    end
  end
end
