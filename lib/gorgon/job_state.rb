require 'observer'

class JobState
  include Observable

  attr_reader :total_files, :remaining_files_count, :failed_files_count

  def initialize total_files
    @total_files = total_files
    @remaining_files_count = total_files
    @failed_files_count = 0
  end

  def finished_files_count
    total_files - remaining_files_count
  end

  def file_finished payload
    @remaining_files_count -= 1
    @failed_files_count += 1 if failed_test?(payload)
    notify_observers
  end

  private

  def failed_test? payload
    payload[:type] == "fail"
  end
end
