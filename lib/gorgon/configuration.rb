require "gorgon/core_ext/hash/deep_merge"
require "yajl"

module Gorgon
  module Configuration
    extend self

    def load_configuration_from_file(first_filename, merge: nil, file_loader: FileLoader)
      ConfigurationParser.new(
        file_loader: file_loader
      ).load_from_files(
        first_filename: first_filename,
        merge_filename: merge
      )
    end

    class ConfigurationParser
      def initialize(file_loader:)
        @file_loader = file_loader
      end

      def load_from_files(first_filename:, merge_filename:)
        load_file(first_filename).deep_merge(load_file(merge_filename))
      end

      private

      def load_file(filename)
        return {} if filename.nil?

        @file_loader.parse(filename)
      end
    end

    module FileLoader
      def self.parse(filename)
        file = File.new(filename, "r")
        Yajl::Parser.new(symbolize_keys: true).parse(file)
      end
    end
  end
end

