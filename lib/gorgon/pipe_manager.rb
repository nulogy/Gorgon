module PipeManager
  private

  def pipe_fork_worker
    pid = fork do
      bind_to_fifos
      worker = Worker.build(@config)
      worker.work
      exit
    end

    fifo_in, fifo_out, fifo_err = wait_for_fifos pid

    pipe_in = File.open(fifo_in, "w")
    pipe_out = File.open(fifo_out)
    pipe_err = File.open(fifo_err)

    return pid, pipe_in, pipe_out, pipe_err
  end

  def pipe_file pid, stream
    "#{pid}_#{stream}.pipe"
  end

  def bind_to_fifos
    fifo_in = pipe_file $$, "in"
    fifo_out = pipe_file $$, "out"
    fifo_err = pipe_file $$, "err"

    system("mkfifo '#{fifo_in}'")
    system("mkfifo '#{fifo_out}'")
    system("mkfifo '#{fifo_err}'")

    @@old_in = $stdin
    $stdin = File.open(fifo_in)

    @@old_out = $stdout
    $stdout = File.open(fifo_out, "w")

    @@old_err = $stderr
    $stderr = File.open(fifo_err, "w")
  end

  def wait_for_fifos pid
    fifo_in = pipe_file pid, "in"
    fifo_out = pipe_file pid, "out"
    fifo_err = pipe_file pid, "err"

    while !File.exist?(fifo_in) || !File.exist?(fifo_out) || !File.exist?(fifo_err)  do
      sleep 0.01
    end

    return fifo_in, fifo_out, fifo_err
  end
end
