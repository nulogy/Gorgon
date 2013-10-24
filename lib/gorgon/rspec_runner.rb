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

      keep_config_modules do
        RSpec::Core::Runner.run(args, err, out)
      end

      out.rewind

      Yajl::Parser.new(:symbolize_keys => true).parse(out.read)
    end

    def runner
      :rspec
    end

    private

    def keep_config_modules
      config_modules = RSpec.configuration.include_or_extend_modules
      yield
      RSpec.configuration.include_or_extend_modules = config_modules
    end
  end
end
