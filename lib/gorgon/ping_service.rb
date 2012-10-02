require 'gorgon/originator_protocol'
require 'gorgon/configuration'
require 'gorgon/originator_logger'
require 'gorgon/colors'

require 'colorize'

class PingService
  include Configuration

  TIMEOUT=4

  def initialize
    @configuration = load_configuration_from_file("gorgon.json")
    @logger = OriginatorLogger.new @configuration[:originator_log_file]
    @protocol = OriginatorProtocol.new @logger
    @listeners = []
  end

  def ping_listeners
    Signal.trap("INT") { disconnect }
    Signal.trap("TERM") { disconnect }

    EventMachine.run do
      @logger.log "Connecting..."
      @protocol.connect @configuration[:connection],  :on_closed => proc {EM.stop}

      @logger.log "Pinging Listeners..."
      @protocol.send_message_to_listeners :ping

      EM.add_timer(TIMEOUT) { disconnect }

      @protocol.receive_payloads do |payload|
        @logger.log "Received #{payload}"

        handle_reply(Yajl::Parser.new(:symbolize_keys => true).parse(payload))
      end
    end
  end

  private

  def disconnect
    @protocol.disconnect
    print_summary
  end

  def handle_reply payload
    if payload[:type] != "ping_response"
      puts "Unexpected message received: #{payload}"
      return
    end

    @listeners << payload
    hostname = payload[:hostname].colorize(Colors::HOST)
    puts "#{hostname} is running Listener version #{payload[:version]} and uses #{payload[:worker_slots]} workers"
  end

  def print_summary
    puts "\n#{@listeners.size} host(s) responded."
  end

  def on_disconnect
    EventMachine.stop
  end
end
