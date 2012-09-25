require 'gorgon/originator_protocol'
require 'gorgon/configuration'
require 'gorgon/originator_logger'

class PingService
  include Configuration

  def initialize
    @configuration = load_configuration_from_file("gorgon.json")
    @logger = OriginatorLogger.new @configuration[:originator_log_file]
    @protocol = OriginatorProtocol.new @logger
  end

  def ping_listeners
    EventMachine.run do
      @logger.log "Connecting..."
      @protocol.connect @configuration[:connection],  :on_closed => method(:on_disconnect)
      @protocol.ping

      sleep 2

      @protocol.disconnect
    end
  end

  def on_disconnect
    EventMachine.stop
  end
end
