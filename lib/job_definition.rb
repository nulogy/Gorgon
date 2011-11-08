require 'yajl'

class JobDefinition
  attr_accessor :file_queue_name, :reply_queue_name, :rsync_command
  def initialize(opts={})
    @file_queue_name = opts[:file_queue_name]
    @reply_queue_name = opts[:reply_queue_name]
    @rsync_command = opts[:rsync_command]
  end

  def to_json
    Yajl::Encoder.encode(to_hash)
  end

  private

  #This can probably be done with introspection somehow, but this is way easier despite being very verbose
  def to_hash
    {:file_queue_name => @file_queue_name, :reply_queue_name => @reply_queue_name, :rsync_command => @rsync_command}
  end
end
