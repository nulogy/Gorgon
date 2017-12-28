require 'rspec/core/formatters/base_formatter'
require 'json'

module RSpec
  module Core
    module Formatters
      class GorgonRspecFormatter < BaseFormatter
        if Formatters.respond_to? :register
          Formatters.register self, :message, :stop, :close
        end

        attr_reader :output

        def initialize(output)
          super
          @failures = []
        end

        def message(notification)
          @failures << rerun_note + notification.message
        end

        def stop(notification=nil)
          @failures += failures(notification).map do |failure|
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
            end
          end
        end

        def failures(notification)
          if !notification.nil?
            notification.examples.select { |e| e.execution_result.status == :failed }
          else
            examples.select { |e| e.execution_result[:status] == "failed" }
          end
        end

        def close(_notification=nil)
          output.write @failures.to_json
          output.close if IO === output && output != $stdout
        end

        private

        def rerun_note
          "\nNOTE: Rerun gorgon after fixing this test. RSpec might not be actually running the other tests due to this non example failure.\n"
        end
      end
    end
  end
end
