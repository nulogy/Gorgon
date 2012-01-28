require 'eventmachine'
require 'socket'

class WorkerWatcher < EventMachine::ProcessWatch
  def initialize(options = {})
    @pid = options[:pid]
    @stdout = options[:stdout]
    @stderr = options[:stderr]
    @reply_exchange = options[:reply_exchange]
  end

  def process_exited
    ignored, status = Process::waitpid2 @pid
    if status.exitstatus != 0
      reply = {:type => :crash,
               :hostname => Socket.gethostname,
               :stdout => @stdout.read,
               :stderr => @stderr.read}
      @reply_exchange.publish(Yajl::Encoder.encode(reply))
    end
  end
end
