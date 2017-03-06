
require 'gorgon/job_definition'

require 'amqp'
require 'uuidtools'

module Gorgon
  class OriginatorProtocol
    def initialize(logger, cluster_id=nil)
      @originator_exchange_name = OriginatorProtocol.originator_exchange_name(cluster_id)
      @job_exchange_name = OriginatorProtocol.job_exchange_name(cluster_id)
      @logger = logger
    end

    def self.originator_exchange_name(cluster_id)
      if cluster_id
        "gorgon.originators.#{cluster_id}"
      else
        "gorgon.originators"
      end
    end

    def self.job_exchange_name(cluster_id)
      if cluster_id
        "gorgon.jobs.#{cluster_id}"
      else
        'gorgon.jobs'
      end
    end

    def connect connection_information, options={}
      @connection = AMQP.connect(connection_information)
      @channel = AMQP::Channel.new(@connection)
      @connection.on_closed { options[:on_closed].call } if options[:on_closed]
      open_queues
    end

    def publish_files files
      @file_queue = @channel.queue("file_queue_" + UUIDTools::UUID.timestamp_create.to_s, :auto_delete => true)

      files.each do |file|
        @channel.default_exchange.publish(file, :routing_key => @file_queue.name)
      end
    end

    def publish_job_to_all job_definition
      job_definition = append_protocol_information_to_job_definition(job_definition)
      @channel.fanout(@job_exchange_name).publish(job_definition.to_json)
    end

    def publish_job_to_one job_definition, listener_queue_name
      job_definition = append_protocol_information_to_job_definition(job_definition)
      @channel.default_exchange.publish(job_definition.to_json, :routing_key => listener_queue_name)
    end

    def append_protocol_information_to_job_definition job_definition
      job_definition = job_definition.dup

      job_definition.file_queue_name = @file_queue.name
      job_definition.reply_exchange_name = @reply_exchange.name

      return job_definition
    end

    def send_message_to_listeners type, body={}
      # TODO: we probably want to use a different exchange for this type of messages
      message = {:type => type, :reply_exchange_name => @reply_exchange.name, :body => body}
      @channel.fanout(@job_exchange_name).publish(Yajl::Encoder.encode(message))
    end

    def receive_payloads
      @reply_queue.subscribe do |payload|
        yield payload
      end
    end

    def receive_new_listener_notifications
      @originator_queue.subscribe do |payload|
        yield payload
      end
    end

    def cancel_job
      @file_queue.purge if @file_queue
      @channel.fanout("gorgon.worker_managers").publish(cancel_message) if @channel
      @logger.log "Cancel Message sent"
    end

    def disconnect
      cleanup_queues_and_exchange
      @connection.disconnect if @connection
    end

    private

    def open_queues
      @reply_queue = @channel.queue("reply_queue_" + UUIDTools::UUID.timestamp_create.to_s, :auto_delete => true)
      @reply_exchange = @channel.direct("reply_exchange_" + UUIDTools::UUID.timestamp_create.to_s, :auto_delete => true)
      @reply_queue.bind(@reply_exchange)

      # Provides a way for new listeners to announce their presence to originators that have already started the job
      @originator_queue = @channel.queue("originator_queue_" + UUIDTools::UUID.timestamp_create.to_s, :auto_delete => true)
      @originator_exchange = @channel.fanout(@originator_exchange_name)
      @originator_queue.bind(@originator_exchange)
    end

    def cleanup_queues_and_exchange
      @reply_queue.delete if @reply_queue
      @file_queue.delete if @file_queue
      @reply_exchange.delete if @reply_exchange
      @originator_queue.delete if @originator_queue
    end

    def cancel_message
      Yajl::Encoder.encode({:action => "cancel_job"})
    end
  end
end
