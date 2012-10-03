require "socket"
require "yajl"
require "bunny"
require 'open4'

class UpdateHandler
  def initialize bunny
    @bunny = bunny
  end

  def handle payload, configuration
    reply_exchange_name = payload[:reply_exchange_name]
    reply = {:type => :updating}
    publish_to reply_exchange_name, reply

    version = payload[:body][:version]
    version_opt = "--version #{version}" if version
    gem = configuration[:bin_gem_path] || "gem"

    cmd = "#{gem} install #{version_opt} gorgon"
    pid, stdin, stdout, stderr = Open4::popen4 cmd
    stdin.close

    ignore, status = Process.waitpid2 pid
    exitstatus = status.exitstatus

    output, errors = [stdout, stderr].map { |p| begin p.read ensure p.close end }

    if exitstatus == 0
      reply = {:type => :update_complete, :command => cmd, :stdout => output,
        :stderr => errors}
      publish_to reply_exchange_name, reply
      @bunny.stop
      exit
    else
      reply = {:type => :update_failed, :command => cmd, :stdout => output, :stderr => errors}
      publish_to reply_exchange_name, reply
   end
  end

  private

  # TODO: factors this out to a class
  def publish_to reply_exchange_name, message
    reply_exchange = @bunny.exchange(reply_exchange_name, :auto_delete => true
)
    reply_exchange.publish(Yajl::Encoder.encode(message.merge(:hostname => Socket.gethostname)))
  end
end
