require "gorgon/configuration"
require "gorgon/testunit_runner"

require "uuidtools"
require "amqp"
require "awesome_print"
require "socket"

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

  def notify_start filename
    reply = {:action => :start, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}
    send_reply reply
  end

  def handle_next_file
    @file_queue.pop do |payload|
      shutdown if payload.nil?

      notify_start payload
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

  def run_file(filename)
    results = run_test_unit_file(filename)
    reply = {:action => :finish, :type => :pass, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}

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
