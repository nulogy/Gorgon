require 'observer'

class JobState
  include Observable

  attr_reader :total_files, :remaining_files_count, :state

  def initialize total_files
    @total_files = total_files
    @remaining_files_count = total_files
    @failed_tests = []
    if @remaining_files_count > 0
      @state = :starting
    else
      @state = :complete
    end
  end

  def failed_files_count
    @failed_tests.count
  end

  def finished_files_count
    total_files - remaining_files_count
  end

  def file_started payload
    raise_if_completed_or_cancelled

    if @state == :starting
      @state = :running
      changed
    end

    notify_observers payload
  end

  def file_finished payload
    raise_if_completed_or_cancelled

    @remaining_files_count -= 1
    @state = :complete if @remaining_files_count == 0

    handle_failed_test payload if failed_test?(payload)

    changed
    notify_observers payload
  end

  def cancel
    @remaining_files_count = 0
    @state = :cancelled
    changed
    notify_observers({})
  end

  def each_failed_test
    @failed_tests.each do |test|
      yield test
    end
  end

  def is_job_complete?
    @state == :complete
  end

  def is_job_cancelled?
    @state == :cancelled
  end

  private

  def handle_failed_test payload
    @failed_tests << payload
  end

  def raise_if_completed_or_cancelled
    raise "JobState#file_finished called when job was already complete" if is_job_complete?
    raise "JobState#file_finished called after job was cancelled" if is_job_cancelled?
  end

  def failed_test? payload
    payload[:type] == "fail"
  end
end
