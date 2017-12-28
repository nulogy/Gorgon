load('~/src/gorgon/lib/gorgon/rspec_runner.rb')
load('~/src/gorgon/lib/gorgon/gorgon_rspec_formatter.rb')

require File.expand_path('../spec/spec_helper.rb', __FILE__)

result1 = RspecRunner.run_file('~/src/gorgon-test/spec/using_shared_example_spec.rb')
puts "############ result1  ##########"
p result1