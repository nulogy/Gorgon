require "gorgon/configuration"
require "gorgon/testunit_runner"
require "gorgon/amqp_service"

require "uuidtools"
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
    config = load_configuration_from_file(@config_filename)[:connection]
    amqp = AmqpService.new config
    reply_exchange_name = @job_definition.reply_exchange_name
    file_queue_name = @job_definition.file_queue_name

    amqp.start_worker file_queue_name, reply_exchange_name do |queue, exchange|
      while filename = queue.pop
        reply = {:action => :start, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}
        exchange.publish reply

        reply = run_file(filename)
        exchange.publish reply
      end
    end
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
end
