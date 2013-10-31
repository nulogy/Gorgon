# -*- encoding: utf-8; mode: ruby -*-

$LOAD_PATH.unshift("#{File.dirname(__FILE__)}")

require "timeout"

require "gorgon_bunny/version"
require "amq/protocol/client"
require "amq/protocol/extensions"

require "gorgon_bunny/framing"
require "gorgon_bunny/exceptions"
require "gorgon_bunny/socket"
require "gorgon_bunny/timeout"

begin
  require "openssl"

  require "gorgon_bunny/ssl_socket"
rescue LoadError => e
  # no-op
end

require "logger"

# Core entities: connection, channel, exchange, queue, consumer
require "gorgon_bunny/session"
require "gorgon_bunny/channel"
require "gorgon_bunny/exchange"
require "gorgon_bunny/queue"
require "gorgon_bunny/consumer"

# GorgonBunny is a RabbitMQ client that focuses on ease of use.
# @see http://rubybunny.info
module GorgonBunny
  # AMQP protocol version GorgonBunny implements
  PROTOCOL_VERSION = AMQ::Protocol::PROTOCOL_VERSION

  #
  # API
  #

  # @return [String] GorgonBunny version
  def self.version
    VERSION
  end

  # @return [String] AMQP protocol version GorgonBunny implements
  def self.protocol_version
    AMQ::Protocol::PROTOCOL_VERSION
  end

  # Instantiates a new connection. The actual connection network
  # connection is started with {GorgonBunny::Session#start}
  #
  # @return [GorgonBunny::Session]
  # @see GorgonBunny::Session#start
  # @see http://rubybunny.info/articles/getting_started.html
  # @see http://rubybunny.info/articles/connecting.html
  # @api public
  def self.new(connection_string_or_opts = {}, opts = {}, &block)
    if connection_string_or_opts.respond_to?(:keys) && opts.empty?
      opts = connection_string_or_opts
    end

    conn = Session.new(connection_string_or_opts, opts)
    @default_connection ||= conn

    conn
  end


  def self.run(connection_string_or_opts = {}, opts = {}, &block)
    raise ArgumentError, 'GorgonBunny#run requires a block' unless block

    client = Session.new(connection_string_or_opts, opts)

    begin
      client.start
      block.call(client)
    ensure
      client.stop
    end

    # backwards compatibility
    :run_ok
  end
end
