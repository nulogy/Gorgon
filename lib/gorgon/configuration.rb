require "yajl"

module Gorgon
  module Configuration
    extend self
    def load_configuration_from_file(filename)
      file = File.new(filename, "r")
      Yajl::Parser.new(:symbolize_keys => true).parse(file)
    end
  end
end
