require 'rspec'
require 'gorgon/gorgon_rspec_formatter'
require 'stringio'
require "yajl"

class RspecRunner
  class << self
    def run_file(filename)
      args = [
              '-f', 'RSpec::Core::Formatters::GorgonRspecFormatter',
              filename
             ]

      err, out = StringIO.new, StringIO.new

      RSpec::Core::Runner.run(args, err, out)
      out.rewind

      Yajl::Parser.new(:symbolize_keys => true).parse(out.read)
    end

    def runner
      :rspec
    end
  end
end
