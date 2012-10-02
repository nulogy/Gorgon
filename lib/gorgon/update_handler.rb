require "socket"
require "yajl"
require "bunny"

class UpdateHandler
  def initialize bunny
    @bunny = bunny
  end

  def handle payload
    reply = {:type => :updating, :hostname => Socket.gethostname}
    publish_to payload[:reply_exchange_name], reply


  end

  # TODO: factors this out to a class
  def publish_to reply_exchange_name, message
    reply_exchange = @bunny.exchange(reply_exchange_name, :auto_delete => true)

    reply_exchange.publish(Yajl::Encoder.encode(message))
  end
end
