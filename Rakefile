require "rubygems"
require "bundler/setup"
Bundler.setup(:default)

$:.push(".")

require "lib/gorgon"

desc "Starts a gorgon job"
task "gorgon:start" do
  o = Originator.new
  o.originate
end

desc "Starts a gorgon listener"
task "gorgon:listen" do
  l = Listener.new
  l.listen
end

desc "Starts a gorgon worker (for internal and debugging use only)"
task "gorgon:work" do
  file_queue_name = ENV["GORGON_FILE_QUEUE_NAME"]
  reply_exchange_name = ENV["GORGON_REPLY_EXCHANGE_NAME"]
  jd = JobDefinition.new(:file_queue_name => file_queue_name, :reply_exchange_name => reply_exchange_name)

  w = Worker.new(jd, "gorgon_listener.json")
  w.work
end