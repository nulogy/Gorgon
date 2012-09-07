require "gorgon/configuration"
require "gorgon/amqp_service"
require 'gorgon/callback_handler'
require "gorgon/g_logger"

require "uuidtools"
require "awesome_print"
require "socket"

module WorkUnit
  def self.run_file filename
    require "gorgon/testunit_runner"
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
  include GLogger

  def self.build(config)

    payload = Yajl::Parser.new(:symbolize_keys => true).parse($stdin.read)
    job_definition = JobDefinition.new(payload)

    connection_config = config[:connection]
    amqp = AmqpService.new connection_config

    callback_handler = CallbackHandler.new(job_definition.callbacks)

    worker_id = UUIDTools::UUID.timestamp_create.to_s
    ENV["GORGON_WORKER_ID"] = worker_id

    params = {
      :amqp => amqp,
      :file_queue_name => job_definition.file_queue_name,
      :reply_exchange_name => job_definition.reply_exchange_name,
      :worker_id => worker_id,
      :test_runner => WorkUnit,
      :callback_handler => callback_handler,
      :log_file => config[:log_file]
    }

    new(params)
  end

  def initialize(params)
    initialize_logger params[:log_file]

    @amqp = params[:amqp]
    @file_queue_name = params[:file_queue_name]
    @reply_exchange_name = params[:reply_exchange_name]
    @worker_id = params[:worker_id]
    @test_runner = params[:test_runner]
    @callback_handler = params[:callback_handler]
  end

  def work
    log "Running before_start callback"
    @callback_handler.before_start
    @amqp.start_worker @file_queue_name, @reply_exchange_name do |queue, exchange|
      while filename = queue.pop
        exchange.publish make_start_message(filename)
        test_results = run_file(filename)
        exchange.publish make_finish_message(filename, test_results)
      end
    end
    ensure
      log "Running after_complete callback"
      @callback_handler.after_complete
  end

  def run_file(filename)
    @test_runner.run_file(filename)
  end

  def make_start_message(filename)
    {:action => :start, :hostname => Socket.gethostname, :worker_id => @worker_id, :filename => filename}
  end

  def make_finish_message(filename, results)
    {:action => :finish, :hostname => Socket.gethostname, :worker_id => @worker_id, :filename => filename}.merge(results)
  end
end
