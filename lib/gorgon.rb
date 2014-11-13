require "gorgon/version"
require "gorgon/originator"
require "gorgon/listener"
require "gorgon/default_callbacks"

module Gorgon
  class << self
    attr_accessor :callbacks
  end
end

# defaults
Gorgon.callbacks = Gorgon::DefaultCallbacks.new
