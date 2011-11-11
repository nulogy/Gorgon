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
        @file_queue.subscribe do |payload|
          handle_file(payload)
        end
      end
    end
  end

  def handle_file(payload)
    run_file(payload)
    @file_queue.status do |num_messages, num_consumers| 
      if num_messages == 0
        #TODO: notify parent listener that we're complete
        @connection.close { EventMachine.stop }
      end
    end
  end

  def run_file(file)
    results = run_test_unit_file(file) 
    reply = {:type => :fail, :hostname => Socket.gethostname, :workerid => @workerid, :failures => results}
    start_t = Time.now
    if !results.empty?
      reply[:failures] = results 
    end

    length = Time.now - start_t
    reply[:time] = length
    @reply_exchange.publish(Yajl::Encoder.encode(reply))
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
