class HostState
  def initialize
    @running_workers = {}
  end

  def file_started worker_id, filename
    if @running_workers.has_key? worker_id
      puts "WARNING: worker #{worker_id} started running a new file, but a 'finish' message has not been received for file #{@running_workers[:filename]}"
    end

    @running_workers[worker_id] = filename
  end

  def file_finished worker_id, filename
    if !@running_workers.has_key? worker_id || @running_workers[:worker_id] != filename
      puts "WARNING: worker #{worker_id} finished running a file, but a 'start' message for that file was not received. File: #{filename}"
    end

    @running_workers.delete(worker_id)
  end

  def total_running_workers
    @running_workers.size
  end

  def each_running_file

  end
end
