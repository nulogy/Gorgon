require 'gorgon/shutdown_manager'

describe Gorgon::ShutdownManager do
  let(:protocol){ double("Originator Protocol", :cancel_job => nil, :disconnect => nil)}

  let(:job_state){ double("JobState", cancel: nil)}

  describe '#cancel_job' do
    it "call JobState#cancel" do
      expect(job_state).to receive(:cancel)

      shutdown_manager(job_state: job_state).cancel_job
    end

    it "tells @protocol to cancel job and disconnect" do
      expect(protocol).to receive(:cancel_job)
      expect(protocol).to receive(:disconnect)

      shutdown_manager(protocol: protocol).cancel_job
    end

    it 'finishes cancelling job even when some cancelling steps fail' do
      expect(protocol).to  receive(:cancel_job).and_raise StandardError
      expect(job_state).to receive(:cancel).and_raise StandardError
      expect(protocol).to receive(:disconnect).and_raise StandardError

      expect {
        shutdown_manager(protocol: protocol, job_state: job_state).cancel_job
      }.to raise_error StandardError
    end
  end

  def shutdown_manager(args)
    defaults = {
        protocol: protocol,
        job_state: job_state
    }
    Gorgon::ShutdownManager.new(defaults.merge(args))
  end
end
