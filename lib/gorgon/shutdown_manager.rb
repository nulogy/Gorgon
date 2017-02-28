module Gorgon
  class ShutdownManager

    def initialize(args)
      @protocol = args.fetch(:protocol)
      @job_state = args.fetch(:job_state)
    end

    def cancel_job
      @protocol.cancel_job if @protocol
    ensure
      cancel_job_state
    end

    private

    def cancel_job_state
      @job_state.cancel if @job_state
    ensure
      disconnect_protocol
    end

    def disconnect_protocol
      @protocol.disconnect if @protocol
    end
  end
end
