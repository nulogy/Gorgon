require 'gorgon/originator_protocol'
require 'gorgon/originator_logger'
require 'gorgon/configuration'

class UpdateService
  include Configuration

  TIMEOUT = 3
  def initialize
    @configuration = load_configuration_from_file("gorgon.json")
    @logger = OriginatorLogger.new @configuration[:originator_log_file]
    @protocol = OriginatorProtocol.new @logger
    @updating = []
  end

  def update version=""
    EM.run do
      @logger.log "Connecting..."
      @protocol.connect @configuration[:connection],  :on_closed => proc {EM.stop}

      @logger.log "Sending Update..."
      @protocol.send_message_to_listeners :update, :version => version

      @protocol.receive_payloads do |payload|
        @logger.log "Received #{payload}"

        handle_reply(Yajl::Parser.new(:symbolize_keys => true).parse(payload))
      end

      EM.add_periodic_timer(TIMEOUT) { disconnect_if_none_updating }
   end
  end

  private

  def disconnect_if_none_updating
    disconnect if @updating.empty?
  end

  def handle_reply payload
    case payload[:type]
    when "updating"
      puts "#{payload[:hostname]} is updating..."
      @updating << payload[:hostname]
    when "update_complete"
      puts "Update complete in #{payload[:hostname]}"
      update_finish payload
    when "update_failed"
      puts "Update failed in #{payload[:hostname]}."
      update_finish payload
    end
  end

  def update_finish payload
    puts "Command was:\n > #{payload[:command]}"
    puts "Output:\n#{payload[:stdout]}#{payload[:stderr]}"
    @updating.delete payload[:hostname]
  end

  def disconnect
    @protocol.disconnect
  end
end
