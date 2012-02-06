class MessageOutputter
  def output_message(payload)
    if payload[:action] == "start"
      $stdout.write("Started running '#{payload[:filename]}' at '#{payload[:hostname]}'\n")
    elsif payload[:action] == "finish"
      print_finish(payload)
    else # to be removed
      ap payload
    end
  end

  private

  def print_finish(payload)
    msg = "Finished running '#{payload[:filename]}' at '#{payload[:hostname]}'\n"
    msg << failure_message(payload[:failures]) if payload[:type] == "fail"
    $stdout.write(msg)
  end

  def failure_message(failures)
    msg = ["Failure:"]
    failures.each do |failure|
      msg << failure
    end
    msg << ''
    msg.join("\n")
  end
end
