# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gorgon/version"

Gem::Specification.new do |s|
  s.name        = "gorgon"
  s.version     = Gorgon::VERSION
  s.authors     = ["Justin Fitzsimmons", "Sean Kirby", "Victor Savkin", "Clemens Park", "Arturo Pie"]
  s.email       = ["justin@fitzsimmons.ca"]
  s.homepage    = ""
  s.summary     = %q{Distributed testing for ruby with centralized management}
  s.description = %q{Gorgon provides a method for distributing the workload of running a ruby test suites. It relies on amqp for message passing, and rsync for the synchronization of source code.}

  s.rubyforge_project = "gorgon"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rake"
  s.add_development_dependency "test-unit"
  s.add_development_dependency "rspec", '~>2.11.0'

  s.add_runtime_dependency "amqp", '~>0.9.7'
  s.add_runtime_dependency "awesome_print"
  s.add_runtime_dependency "open4", '~>1.3.0'
  s.add_runtime_dependency "yajl-ruby", '~>1.1.0'
  s.add_runtime_dependency "uuidtools", '~>2.1.3'
  s.add_runtime_dependency "bunny", '~>0.8.0'
  s.add_runtime_dependency "ruby-progressbar", '~>1.0.1'
  s.add_runtime_dependency "colorize", '~>0.5.8'
end
