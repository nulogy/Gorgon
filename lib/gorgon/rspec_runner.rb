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

      Yajl::Parser.new(symbolize_keys: true).parse(out.read)
    end

    def runner
      :rspec
    end

    private

    def keep_config_modules
      orig_configuration = ::RSpec.configuration.clone
      orig_shared_example_groups = ::RSpec.world.instance_variable_get(:@shared_example_group_registry).clone
      yield
    ensure
      ::RSpec.clear_examples
      ::RSpec.instance_variable_set(:@configuration, orig_configuration)
      ::RSpec.world.instance_variable_set(:@shared_example_group_registry, orig_shared_example_groups)
    end
  end
end
