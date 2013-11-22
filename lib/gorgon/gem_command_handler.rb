require "socket"
require "yajl"

require "gorgon_bunny/lib/gorgon_bunny"
require 'open4'

class GemCommandHandler
  def initialize bunny
    @bunny = bunny
  end

  def handle payload, configuration
    reply_exchange_name = payload[:reply_exchange_name]
    publish_to reply_exchange_name, :type => :running_command

    gem = configuration[:bin_gem_path] || "gem"

    cmd = "#{gem} #{payload[:body][:gem_command]} gorgon"
    pid, stdin, stdout, stderr = Open4::popen4 cmd
    stdin.close

    ignore, status = Process.waitpid2 pid
    exitstatus = status.exitstatus

    output, errors = [stdout, stderr].map { |p| begin p.read ensure p.close end }

    if exitstatus == 0
      reply = {:type => :command_completed, :command => cmd, :stdout => output,
        :stderr => errors}
      publish_to reply_exchange_name, reply
      @bunny.stop
      exit     # TODO: for now exit until we implement a command to exit listeners
    else
      reply = {:type => :command_failed, :command => cmd, :stdout => output, :stderr => errors}
      publish_to reply_exchange_name, reply
   end
  end

  private

  # TODO: factors this out to a class
  def publish_to reply_exchange_name, message
    reply_exchange = @bunny.exchange(reply_exchange_name, :auto_delete => true, :type => :fanout)
    reply_exchange.publish(Yajl::Encoder.encode(message.merge(:hostname => Socket.gethostname)))
  end
end
