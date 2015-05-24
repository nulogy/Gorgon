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
      orig_configuration = ::RSpec.configuration.clone
      yield
      RSpec.reset
      ::RSpec.instance_variable_set(:@configuration, orig_configuration)
    end
  end
end
