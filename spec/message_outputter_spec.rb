require File.expand_path('../../lib/gorgon/message_outputter', __FILE__)

describe MessageOutputter do
  let (:message_outputter) { MessageOutputter.new }
  describe "#output_message" do
    it "prints start messages" do
      payload = {:action => "start",
                 :hostname => "host",
                 :filename => "filename"}
      $stdout.should_receive(:write).with("Started running 'filename' at 'host'\n")
      message_outputter.output_message(payload)
    end

    it "prints finish messages" do
      payload = {:action => "finish",
                 :hostname => "host",
                 :filename => "filename"}
      $stdout.should_receive(:write).with("Finished running 'filename' at 'host'\n")
      message_outputter.output_message(payload)
    end

    it "prints failure messages when a test finishes with failures" do
      payload = {:action => "finish",
                 :type => "fail",
                 :hostname => "host",
                 :filename => "filename",
                 :failures => [
                   "failure"
                 ]}

      $stdout.should_receive(:write).with("Finished running 'filename' at 'host'\nFailure:\nfailure\n")
      message_outputter.output_message(payload)
    end
  end
end
