require 'gorgon/crash_reporter'

describe "CrashReporter" do
  let(:exchange) { stub("GorgonBunny Exchange", :publish => nil) }
  let(:info) { {
      :out_file => "stdout_file", :err_file => "stderr_file", :footer_text => "Text"
    } }

  let(:container_class) do
    Class.new do
      extend(CrashReporter)
    end
  end

  describe "#report_crash" do
    it "tails output file to get last few lines and cat err file to get all lines" do
      container_class.should_receive(:'`').once.
        with(/tail.*stdout_file/).and_return ""
      container_class.should_receive(:'`').once.
        with(/cat.*stderr_file/).and_return ""
      container_class.report_crash exchange, info
    end

    it "calls send_crash_message" do
      container_class.stub!(:'`').and_return "stdout text", "stderr text "
      container_class.should_receive(:send_crash_message).with(exchange, "stdout text", "stderr text Text")
      container_class.report_crash exchange, info
    end

    it "returns last lines of output from stderr message and footer text" do
      container_class.stub!(:'`').and_return "stdout text", "stderr text "
      container_class.stub!(:send_crash_message)
      result = container_class.report_crash exchange, info
      result.should == "stdout text\nstderr text Text"
    end
  end

  describe "#send_crash_message" do
    it "sends message with output and errors from syncer using reply_exchange " do
      reply = {:type => :crash, :hostname => Socket.gethostname, :stdout => "some output",
        :stderr => "some errors"}
      exchange.should_receive(:publish).with(Yajl::Encoder.encode(reply))
      container_class.send_crash_message exchange, "some output", "some errors"
    end
  end
end
