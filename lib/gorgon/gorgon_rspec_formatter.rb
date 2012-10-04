require 'rspec/core/formatters/base_formatter'
require 'json'

module RSpec
  module Core
    module Formatters
      class GorgonRspecFormatter < BaseFormatter
        attr_reader :output

        def initialize(output)
          super
          @failures = []
        end

        def message(message)
          @failures += message unless @failures.empty?
        end

        def stop
          super
          failures = examples.select { |e| e.execution_result[:status] == "failed" }

          @failures += failures.map do |failure|
            {
              :test_name => "#{failure.full_description}: " \
              "line #{failure.metadata[:line_number]}",
              :description => failure.description,
              :full_description => failure.full_description,
              :status => failure.execution_result[:status],
              :file_path => failure.metadata[:file_path],
              :line_number  => failure.metadata[:line_number],
            }.tap do |hash|
              if e=failure.exception
                hash[:class] = e.class.name
                hash[:message] = e.message
                hash[:location] = e.backtrace
              end
            end
          end
        end

        def close
          output.write @failures.to_json
          output.close if IO === output && output != $stdout
        end
      end
    end
  end
end
