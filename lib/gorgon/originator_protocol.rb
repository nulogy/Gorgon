require 'gorgon/job_definition'

require 'amqp'
require 'uuidtools'

class OriginatorProtocol
  def initialize logger
    @logger = logger
  end

  def connect connection_information, options={}
    @connection = AMQP.connect(connection_information)
    @channel = AMQP::Channel.new(@connection)
    @connection.on_closed { options[:on_closed].call } if options[:on_closed]
    open_queues
  end

  def publish_files files
    @file_queue = @channel.queue(UUIDTools::UUID.timestamp_create.to_s)

    files.each do |file|
      @channel.default_exchange.publish(file, :routing_key => @file_queue.name)
    end
  end

  def publish_job job_definition
    job_definition.file_queue_name = @file_queue.name
    job_definition.reply_exchange_name = @reply_exchange.name

    @channel.fanout("gorgon.jobs").publish(job_definition.to_json)
  end

  def ping_listeners
    # TODO: we probably want to use a different exchange for pinging when we add more services
    message = {:type => "ping", :reply_exchange_name => @reply_exchange.name}
    @channel.fanout("gorgon.jobs").publish(Yajl::Encoder.encode(message))
  end

  def receive_payloads
    @reply_queue.subscribe do |payload|
      yield payload
    end
  end

  def cancel_job
    @file_queue.purge if @file_queue
    @channel.fanout("gorgon.worker_managers").publish(cancel_message)
    @logger.log "Cancel Message sent"
  end

  def disconnect
    cleanup_queues
    @connection.disconnect
  end

  private

  def open_queues
    @reply_queue = @channel.queue(UUIDTools::UUID.timestamp_create.to_s)
    @reply_exchange = @channel.direct(UUIDTools::UUID.timestamp_create.to_s)
    @reply_queue.bind(@reply_exchange)
  end

  def cleanup_queues
    @reply_queue.delete if @reply_queue
    @file_queue.delete if @file_queue
  end

  def cancel_message
    Yajl::Encoder.encode({:action => "cancel_job"})
  end
end
