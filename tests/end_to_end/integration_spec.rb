require "open4"

def wait_until_program_is_ready(command_stdout_read, ready_message)
  while true
    line = command_stdout_read.readline
    puts line
    if line =~ ready_message
      return
    end
  end
end

def run_in_background(command:, ready_message:)
  command_stdout_read, command_stdout_write = IO.pipe
  command_pid = fork do
    Open4::spawn(command, stdout: command_stdout_write, stderr: $stderr)
  end
  command_stdout_write.close

  wait_until_program_is_ready(command_stdout_read, ready_message)
  command_pid
end

describe "Gorgon integration spec" do

  around(:all) do |example|
    begin
      rabbit_pid = run_in_background(
        command: "rabbitmq-server", ready_message: /Starting broker... completed/
      )

      listener_pid = run_in_background(
        command: "gorgon listen", ready_message: /Welcome to Gorgon/
      )

      example.call

    ensure
      puts "stopping Rabbit"
      puts "stopping Listener"
      Process.kill('INT', rabbit_pid)
      Process.kill('INT', listener_pid)
      Process.wait2 listener_pid
      Process.wait2 rabbit_pid
    end
  end

  it "passes once" do
    expect(true).to eq(true)
  end
end
