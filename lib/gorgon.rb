require "gorgon/version"
require "gorgon/originator"
require "gorgon/listener"

module Gorgon
  class << self
    attr_accessor :callbacks
  end
end
