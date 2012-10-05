require 'rspec'
require 'stringio'
require "yajl"

require_relative "gorgon_rspec_formatter"

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
