require 'yajl'

module Gorgon
  class JobDefinition
    attr_accessor :file_queue_name, :reply_exchange_name, :sync, :callbacks

    def initialize(opts={})
      @file_queue_name = opts[:file_queue_name]
      @reply_exchange_name = opts[:reply_exchange_name]
      @callbacks = opts[:callbacks]
      @sync = opts[:sync]
    end

    def to_json
      Yajl::Encoder.encode(to_hash)
    end

    private

    #This can probably be done with introspection somehow, but this is way easier despite being very verbose
    def to_hash
      {
        :type => "job_definition",
        :file_queue_name => @file_queue_name,
        :reply_exchange_name => @reply_exchange_name,
        :sync => @sync,
        :callbacks => @callbacks
      }
    end
  end
end
