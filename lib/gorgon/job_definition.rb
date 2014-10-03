require 'yajl'

class JobDefinition
  attr_accessor :file_queue_name, :reply_exchange_name, :source_tree_path, :sync, :callbacks

  def initialize(opts={})
    @file_queue_name = opts[:file_queue_name]
    @reply_exchange_name = opts[:reply_exchange_name]
    @source_tree_path = opts[:source_tree_path]
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
      :source_tree_path => @source_tree_path,
      :sync => @sync,
      :callbacks => @callbacks
    }
  end
end
