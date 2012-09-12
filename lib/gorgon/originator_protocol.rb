require 'amqp'

class OriginatorProtocol
  def connect connection_information, options={}
    @connection = AMQP.connect(connection_information)
    @channel = AMQP::Channel.new(@connection)
    @connection.on_closed { options[:on_closed] } if options[:on_closed]
  end

  def publish_files files
  end

  def publish_job job_definition
  end

  def receive_payload
  end

  def cleanup options={}
  end
end
