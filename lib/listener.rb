require "configuration"
require "yajl"
require "amqp"
require "awesome_print"
require "job_definition"
require "worker"
require "open4"
require "tmpdir"
require "socket"

class Listener
  include Configuration

  def initialize
    @config_filename = Dir.pwd + "gorgon_listener.json"
  end

  def listen
    AMQP.start(connection_information) do |connection|
      AMQP::Channel.new(connection) do |channel|
        @channel = channel
        channel.queue("", :auto_delete => true, :exclusive => true) do |job_queue, reply|
          exchange = channel.fanout("gorgon.jobs")
          job_queue.bind(exchange)
          handle_jobs(job_queue)
        end
      end
    end
  end

  def handle_jobs(job_queue)
    job_queue.subscribe do |json_payload|
      payload = Yajl::Parser.new(:symbolize_keys => true).parse(json_payload)
      @job_definition = JobDefinition.new(payload)
      @reply_exchange = @channel.direct(@job_definition.reply_exchange_name)
      Dir.mktmpdir("gorgon") do |tempdir|
        Dir.chdir(tempdir)
        system("sleep 3; rsync -r --rsh=ssh #{@job_definition.source_tree_path}/* .")
        fork_workers
      end
    end
  end

  def fork_workers
    threads = []
    configuration[:worker_slots].times do
      thread_info = {:stdout => '', :stderr => ''}
      thread_info[:thread] = Open4::bg "gorgon work #{@job_definition.file_queue_name} #{@job_definition.reply_exchange_name} '#{@config_filename}'", 
        1 => thread_info[:stdout], 2 => thread_info[:stderr]
      threads << thread_info
    end

    threads.each do |thread_info|
      begin
        thread_info[:thread].exitstatus
      rescue
        reply = {:type => :crash,
                 :hostname => Socket.gethostname,
                 :stdout => thread_info[:stdout],
                 :stderr => thread_info[:stderr]}
        @reply_exchange.publish(Yajl::Encoder.encode(reply))
      end
    end
  end

  def connection_information
    configuration[:connection]
  end

  def configuration
    @configuration ||= load_configuration_from_file("gorgon_listener.json")
  end
end
