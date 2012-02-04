require "gorgon/configuration"
require "gorgon/testunit_runner"
require "gorgon/amqp_service"

require "uuidtools"
require "awesome_print"
require "socket"

module WorkUnit
  def self.run_file filename
    start_t = Time.now
    results = TestRunner.run_file(filename)
    length = Time.now - start_t

    if results.empty?
      {:failures => [], :type => :pass, :time => length}
    else
      {:failures => results, :type => :fail, :time => length}
    end
  end
end

class Worker
  def self.build(job_definition, config_filename)
    config = Configuration.load_configuration_from_file(config_filename)[:connection]
    amqp = AmqpService.new config

    worker_id = UUIDTools::UUID.timestamp_create.to_s

    new(amqp, job_definition.file_queue_name, job_definition.reply_exchange_name, worker_id, WorkUnit)
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
        exchange.publish make_start_message(filename)
        test_results = run_file(filename)
        exchange.publish make_finish_message(filename, test_results)
      end
    end
  end

  def run_file(filename)
    @test_runner.run_file(filename)
  end

  def make_start_message(filename)
    {:action => :start, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}
  end

  def make_finish_message(filename, results)
    {:action => :finish, :hostname => Socket.gethostname, :workerid => @workerid, :filename => filename}.merge(results)
  end
end
