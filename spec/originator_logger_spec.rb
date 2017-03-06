require 'gorgon/originator_logger'

describe Gorgon::OriginatorLogger do
  before do
    Gorgon::OriginatorLogger.any_instance.stub(:initialize_logger)
  end

  let (:originator_logger) { Gorgon::OriginatorLogger.new "" }

  describe "#log_message" do
    it "prints start messages" do
      payload = {:action => "start",
                 :hostname => "host",
                 :filename => "filename",
                 :worker_id => "a_worker_id"}
      originator_logger.should_receive(:log).with("Started running 'filename' at 'host:a_worker_id'")
      originator_logger.log_message(payload)
    end

    it "prints finish messages" do
      payload = {:action => "finish",
                 :hostname => "host",
                 :filename => "filename",
                 :worker_id => "a_worker_id"}
      originator_logger.should_receive(:log).with("Finished running 'filename' at 'host:a_worker_id'")
      originator_logger.log_message(payload)
    end

    it "prints failure messages when a test finishes with failures" do
      payload = {:action => "finish",
                 :type => "fail",
                 :hostname => "host",
                 :filename => "filename",
                 :worker_id => "a_worker_id",
                 :failures => [
                   "failure"
                 ]}

      originator_logger.should_receive(:log).with("Finished running 'filename' at 'host:a_worker_id'failure\n")
      originator_logger.log_message(payload)
    end
  end
end
