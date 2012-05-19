class CallbackHandler
  def initialize(config)
    @config = config || {}
  end

  def before_start
    system(@config[:before_start]) if @config[:before_start]
  end

  def after_complete
    system(@config[:after_complete]) if @config[:after_complete]
  end
end