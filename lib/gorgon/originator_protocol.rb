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
    files.each do |file|
      @channel.default_exchange.publish(file, :routing_key => @file_queue.name)
    end
  end

  def publish_job job_definition
    job_definition.file_queue_name = @file_queue.name
    job_definition.reply_exchange_name = @reply_exchange.name

    @channel.fanout("gorgon.jobs").publish(job_definition.to_json)
  end

  def receive_payloads
    @reply_queue.subscribe do |payload|
      yield payload
    end
  end

  def cancel_job
    @file_queue.purge
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
    @file_queue = @channel.queue(UUIDTools::UUID.timestamp_create.to_s)
  end

  def cleanup_queues
    @reply_queue.delete
    @file_queue.delete
  end
end
