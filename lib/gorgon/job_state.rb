require 'gorgon/host_state'

require 'observer'

class JobState
  include Observable

  attr_reader :total_files, :remaining_files_count, :state, :crashed_hosts

  def initialize total_files
    @total_files = total_files
    @remaining_files_count = total_files
    @failed_tests = []
    @crashed_hosts = []
    @hosts = {}

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
    raise_if_completed

    if @state == :starting
      @state = :running
    end

    file_started_update_host_state payload

    changed
    notify_observers payload
  end

  def file_finished payload
    raise_if_completed

    @remaining_files_count -= 1
    @state = :complete if @remaining_files_count == 0

    handle_failed_test payload if failed_test?(payload)

    @hosts[payload[:hostname]].file_finished payload[:worker_id], payload[:filename]

    changed
    notify_observers payload
  end

  def gorgon_crash_message payload
    @crashed_hosts << payload[:hostname]
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

  def each_running_file
    @hosts.each do |hostname, host|
      host.each_running_file do |filename|
        yield hostname, filename
      end
    end
  end

  def total_running_hosts
    @hosts.size
  end

  def total_running_workers
    result = 0
    @hosts.each do |hostname, host|
      result += host.total_running_workers
    end
    result
  end

  def is_job_complete?
    @state == :complete
  end

  def is_job_cancelled?
    @state == :cancelled
  end

  private

  def file_started_update_host_state payload
    hostname = payload[:hostname]
    @hosts[hostname] = HostState.new if @hosts[hostname].nil?
    @hosts[hostname].file_started payload[:worker_id], payload[:filename]
  end

  def handle_failed_test payload
    @failed_tests << payload
  end

  def raise_if_completed
    raise "JobState#file_finished called when job was already complete" if is_job_complete?
    puts "NOTICE: JobState#file_finished called after job was cancelled" if is_job_cancelled?
  end

  def failed_test? payload
    payload[:type] == "fail" || payload[:type] == "crash"
  end
end
