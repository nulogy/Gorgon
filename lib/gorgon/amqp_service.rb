require 'gorgon_bunny'
require 'yajl'

class AmqpQueueDecorator
  def initialize queue
    @queue = queue
  end

  def pop
    m = @queue.pop
    p = m[:payload]
    p == :queue_empty ? nil : p
  end
end

class AmqpExchangeDecorator
  def initialize exchange
    @exchange = exchange
  end

  def publish msg
    serialized_msg = Yajl::Encoder.encode(msg)
    @exchange.publish serialized_msg
  end
end

class AmqpService
  def initialize connection_config
    @connection_config = connection_config.merge(:spec => "09")
  end

  def start_worker file_queue_name, reply_exchange_name
    GorgonBunny.run @connection_config do |b|
      queue = b.queue file_queue_name
      exchange = b.exchange reply_exchange_name
      yield AmqpQueueDecorator.new(queue), AmqpExchangeDecorator.new(exchange)
    end
  end
end
