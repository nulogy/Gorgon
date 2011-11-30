require 'job_definition'
require 'amqp'
require 'awesome_print'
require 'configuration'
require 'uuidtools'

class Originator
  include Configuration

  def initialize
    @configuration = nil
    @channel = nil
  end

  def originate
    begin
      Signal.trap("INT") { ctrl_c }
      Signal.trap("TERM") { ctrl_c }

      publish
    rescue Exception
      puts "Unhandled exception in originator:"
      puts $!.message
      puts $!.backtrace.join("\n")
      puts "----------------------------------"
      puts "Now attempting to cancel the job."
      cancel_job
    end
  end

  def ctrl_c
    puts "Ctrl-C received! Just wait a moment while I clean up..."
    cancel_job
  end

  def cancel_job
    @file_queue.purge

    @file_count_remaining = 0
    cleanup_if_job_complete
  end

  def publish
    EventMachine.run do
      connect
      @reply_queue = @channel.queue(UUIDTools::UUID.timestamp_create.to_s)
      @reply_exchange = @channel.direct(UUIDTools::UUID.timestamp_create.to_s)
      @reply_queue.bind(@reply_exchange)
      @file_queue = @channel.queue(UUIDTools::UUID.timestamp_create.to_s)

      publish_files
      publish_job

      @reply_queue.subscribe do |payload|
        handle_reply(payload)
      end
    end
  end

  def cleanup_if_job_complete
    if @file_count_remaining == 0
      cleanup_queues
      @connection.disconnect { EventMachine.stop }
    end
  end

  def handle_reply(payload)
    @file_count_remaining -= 1
    payload = Yajl::Parser.new(:symbolize_keys => true).parse(payload)
    ap payload
    cleanup_if_job_complete
  end
  
  def cleanup_queues
    @reply_queue.delete
    @file_queue.delete
  end

  def publish_files
    files.each do |file|
      @channel.default_exchange.publish(file, :routing_key => @file_queue.name)
    end
    @file_count_remaining = files.count
  end

  def publish_job
    @channel.fanout("gorgon.jobs").publish(job_definition.to_json)
  end

  def connect
    @connection = AMQP.connect(connection_information)
    @channel = AMQP::Channel.new(@connection)
    @connection.on_closed { on_disconnect }
  end

  def on_disconnect

  end

  def connection_information
    configuration[:connection]
  end

  def files
    configuration[:files].reduce([]) do |memo, obj|
      memo.concat(Dir[obj])
    end.uniq
  end

  def job_definition
    JobDefinition.new(@configuration[:job].merge({:file_queue_name => @file_queue.name, :reply_exchange_name => @reply_exchange.name}))
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon.json")
  end
end
