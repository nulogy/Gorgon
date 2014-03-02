require 'gorgon/shutdown_manager'

describe ShutdownManager do
  let(:protocol){ stub("Originator Protocol", :cancel_job => nil, :disconnect => nil)}

  let(:job_state){ stub("JobState", cancel: nil)}
  let(:rsync_daemon) { stub("Rsync Daemon", :stop => true)}

  describe '#cancel_job' do
    it "call JobState#cancel" do
      job_state.should_receive(:cancel)

      shutdown_manager(job_state: job_state).cancel_job
    end

    it "tells @protocol to cancel job and disconnect" do
      protocol.should_receive(:cancel_job)
      protocol.should_receive(:disconnect)

      shutdown_manager(protocol: protocol).cancel_job
    end

    it "stops the rsync daemon" do
      rsync_daemon.should_receive(:stop)

      shutdown_manager(rsync_daemon: rsync_daemon).cancel_job
    end

    it 'finishes cancelling job even when some cancelling steps fail' do
      protocol.should_receive(:cancel_job).and_raise StandardError
      job_state.should_receive(:cancel).and_raise StandardError
      protocol.should_receive(:disconnect).and_raise StandardError
      rsync_daemon.should_receive(:stop).and_raise StandardError

      expect {
        shutdown_manager(protocol: protocol, job_state: job_state, rsync_daemon: rsync_daemon).cancel_job
      }.to raise_error StandardError
    end
  end

  def shutdown_manager(args)
    defaults = {
        protocol: protocol,
        job_state: job_state,
        rsync_daemon: rsync_daemon
    }
    ShutdownManager.new(defaults.merge(args))
  end
end