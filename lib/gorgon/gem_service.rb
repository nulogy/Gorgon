require 'gorgon/originator_protocol'
require 'gorgon/originator_logger'
require 'gorgon/configuration'

class GemService
  include Configuration

  TIMEOUT = 3
  def initialize
    @configuration = load_configuration_from_file("gorgon.json")
    @logger = OriginatorLogger.new @configuration[:originator_log_file]
    @protocol = OriginatorProtocol.new @logger
    @running = []
  end

  def run command
    EM.run do
      @logger.log "Connecting..."
      @protocol.connect @configuration[:connection],  :on_closed => proc {EM.stop}

      @logger.log "Sending gem command #{command}..."
      @protocol.send_message_to_listeners :gem_command, :command => command

      @protocol.receive_payloads do |payload|
        @logger.log "Received #{payload}"

        handle_reply(Yajl::Parser.new(:symbolize_keys => true).parse(payload))
      end

      EM.add_periodic_timer(TIMEOUT) { disconnect_if_none_running }
   end
  end

  private

  def disconnect_if_none_running
    disconnect if @running.empty?
  end

  def handle_reply payload
    case payload[:type]
    when "running_command"
      puts "#{payload[:hostname]} is running command #{payload[:command]}..."
      @running << payload[:hostname]
    when "command_completed"
      puts "Command #{payload[:command]} completed in #{payload[:hostname]}"
      command_finished payload
    when "command_failed"
      puts "Command #{payload[:command]} failed in #{payload[:hostname]}."
      command_finished payload
    end
  end

  def command_finished payload
    puts "Output:\n#{payload[:stdout]}#{payload[:stderr]}"
    @running.delete payload[:hostname]
  end

  def disconnect
    @protocol.disconnect
  end
end
