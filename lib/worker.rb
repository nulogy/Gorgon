require "configuration"
require "uuidtools"
require "amqp"
require "awesome_print"
require "socket"
require "testunit_runner"

class Worker
  include Configuration

  def initialize(job_definition, config_filename)
    @job_definition = job_definition
    @config_filename = config_filename
    @workerid = UUIDTools::UUID.timestamp_create.to_s
  end

  def work
    AMQP.start(connection_information) do |connection|
      @connection = connection
      AMQP::Channel.new(connection) do |channel|
        setup_reply_exchange(channel)

        @file_queue = channel.queue(@job_definition.file_queue_name)
        handle_next_file
      end
    end
  end

  def shutdown
    @connection.close { EventMachine.stop }
  end

  def handle_next_file
    @file_queue.pop do |payload|
      shutdown if payload.nil?

      operation = proc do
        reply = run_file(payload)
      end

      callback = proc do |reply|
        send_reply reply
        handle_next_file
      end

      EventMachine.defer(operation, callback)
    end
  end

  def send_reply reply
    @reply_exchange.publish(Yajl::Encoder.encode(reply))
  end

  def run_file(file)
    results = run_test_unit_file(file) 
    reply = {:type => :pass, :hostname => Socket.gethostname, :workerid => @workerid}

    start_t = Time.now

    if !results.empty?
      reply[:failures] = results 
      reply[:type] = :fail
    end

    length = Time.now - start_t
    reply[:time] = length
    reply
  end

  def setup_reply_exchange(channel)
    @reply_exchange = channel.direct(@job_definition.reply_exchange_name)
  end

  def connection_information
    configuration[:connection]
  end

  def configuration
    @configuration ||= load_configuration_from_file(@config_filename)
  end
end
