require "gorgon/configuration"
require "gorgon/testunit_runner"
require "gorgon/amqp_service"

require "uuidtools"
require "awesome_print"
require "socket"

class Worker
  def self.build(job_definition, config_filename)
    config = Configuration.load_configuration_from_file(config_filename)[:connection]
    amqp = AmqpService.new config

    workerid = UUIDTools::UUID.timestamp_create.to_s

    new(amqp, job_definition.file_queue_name, job_definition.reply_exchange_name, worker_id, TestRunner)
  end

  def initialize(amqp, file_queue_name, reply_exchange_name, test_runner)
    @amqp = amqp
    @file_queue_name = file_queue_name
    @reply_exchange_name = reply_exchange_name
    @test_runner = test_runner
  end

  def work
    @amqp.start_worker @file_queue_name, @reply_exchange_name do |queue, exchange|
      while filename = queue.pop
        reply = {:action => :start, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}
        exchange.publish reply

        reply = run_file(filename)
        exchange.publish reply
      end
    end
  end

  def run_file(filename)
    start_t = Time.now

    results = @test_runner.run_file(filename)
    reply = {:action => :finish, :type => :pass, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}

    if !results.empty?
      reply[:failures] = results 
      reply[:type] = :fail
    end

    length = Time.now - start_t
    reply[:time] = length
    reply
  end
end
