require 'gorgon/g_logger'

class OriginatorLogger
  include GLogger

  def initialize log_file
    initialize_logger log_file
  end

  def log_message(payload)
    if payload[:action] == "start"
      log("Started running '#{payload[:filename]}' at '#{payload[:hostname]}'")
    elsif payload[:action] == "finish"
      print_finish(payload)
    else # to be removed
      ap payload
    end
  end

  private

  def print_finish(payload)
    msg = "Finished running '#{payload[:filename]}' at '#{payload[:hostname]}'"
    msg << failure_message(payload[:failures]) if payload[:type] == "fail"
    log msg
  end

  def failure_message(failures)
    msg = []
    failures.each do |failure|
      msg << failure
    end
    msg << ''
    msg.join("\n")
  end
end
