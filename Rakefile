require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => [:spec, :end_to_end_test]

desc "Run end to end test using RabbitMQ and a gorgon listener"
task :end_to_end_test do
  puts " 🤖 WARNING: End to end tests have not been automated yet. Follow instructions in the Readme to run them manually."
end
