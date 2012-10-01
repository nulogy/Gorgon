module CrashReporter
  OUTPUT_LINES_TO_REPORT = 40

  def report_crash reply_exchange, info
    stdout = `tail -n #{OUTPUT_LINES_TO_REPORT} #{info[:out_file]}`
    stderr = `tail -n #{OUTPUT_LINES_TO_REPORT} #{info[:err_file]}` + \
    info[:footer_text]

    send_crash_message reply_exchange, stdout, stderr

    "#{stdout}\n#{stderr}"
  end

  def send_crash_message reply_exchange, output, error
    reply = {:type => :crash, :hostname => Socket.gethostname,
      :stdout => output, :stderr => error}
    reply_exchange.publish(Yajl::Encoder.encode(reply))
  end
end
