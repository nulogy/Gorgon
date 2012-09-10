require 'observer'

class JobState
  include Observable

  attr_reader :total_files, :remaining_files_count, :failed_files_count, :state

  def initialize total_files
    @total_files = total_files
    @remaining_files_count = total_files
    @failed_files_count = 0
    if @remaining_files_count > 0
      @state = :starting
    else
      @state = :complete
    end
  end

  def finished_files_count
    total_files - remaining_files_count
  end

  def file_started
    raise_if_completed_or_cancelled
    @state = :running if @state == :starting
  end

  def file_finished payload
    raise_if_completed_or_cancelled

    @remaining_files_count -= 1
    @state = :complete if @remaining_files_count == 0

    @failed_files_count += 1 if failed_test?(payload)
    notify_observers
  end

  def cancel
    @remaining_files_count = 0
    @state = :cancelled
  end

  def is_job_complete?
    @state == :complete
  end

  def is_job_cancelled?
    @state == :cancelled
  end

  private

  def raise_if_completed_or_cancelled
    raise "JobState#file_finished called when job was already complete" if is_job_complete?
    raise "JobState#file_finished called after job was cancelled" if is_job_cancelled?
  end

  def failed_test? payload
    payload[:type] == "fail"
  end
end
