require 'rspec/core/formatters/base_formatter'
require 'json'

module RSpec
  module Core
    module Formatters
      class GorgonRspecFormatter < BaseFormatter
        if Formatters.respond_to? :register
          Formatters.register self, :message, :stop, :close, :seed
        end

        attr_reader :output

        def initialize(output)
          super
          @execution_results = []
          @failures = []
          @seed = nil
        end

        def message(_notification)
        end

        def stop(notification=nil)
          @execution_results += failures(notification)
        end

        def seed(seed_notification)
          return unless seed_notification.seed_used?

          @seed = seed_notification.seed
        end

        def close(_notification=nil)
          @failures += transform_execution_results

          output.write @failures.to_json
          output.close if IO === output && output != $stdout
        end

        private

        def failures(notification)
          if !notification.nil?
            notification.examples.select { |e| e.execution_result.status == :failed }
          else
            examples.select { |e| e.execution_result[:status] == "failed" }
          end
        end

        def transform_execution_results
          @execution_results.map do |failure|
            {
              test_name: "#{failure.full_description}: line #{failure.metadata[:line_number]}",
              description: failure.description,
              full_description: failure.full_description,
              status: :failed,
              file_path: failure.metadata[:file_path],
              line_number: failure.metadata[:line_number]
            }.tap do |hash|
              exception = failure.exception
              unless exception.nil?
                hash[:class] = exception.class.name
                hash[:message] = exception.message
                hash[:location] = exception.backtrace
              end

              hash[:seed] = @seed if @seed
            end
          end
        end
      end
    end
  end
end
