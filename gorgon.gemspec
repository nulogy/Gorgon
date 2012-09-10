# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "gorgon/version"

Gem::Specification.new do |s|
  s.name        = "gorgon"
  s.version     = Gorgon::VERSION
  s.authors     = ["Justin Fitzsimmons", "Sean Kirby", "Victor Savkin", "Clemens Park"]
  s.email       = ["justin@fitzsimmons.ca"]
  s.homepage    = ""
  s.summary     = %q{Distributed testing for ruby with centralized management}
  s.description = %q{Gorgon provides a method for distributing the workload of running a ruby test suites. It relies on amqp for message passing, and rsync for the synchronization of source code.}

  s.rubyforge_project = "gorgon"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "rspec"
  s.add_development_dependency "rake"

  s.add_runtime_dependency "amqp"
  s.add_runtime_dependency "awesome_print"
  s.add_runtime_dependency "open4"
  s.add_runtime_dependency "yajl-ruby"
  s.add_runtime_dependency "uuidtools"
  s.add_runtime_dependency "test-unit"
  s.add_runtime_dependency "bunny"
  s.add_runtime_dependency "ruby-progressbar"
  s.add_runtime_dependency "colorize"
end
