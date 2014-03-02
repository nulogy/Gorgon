$:.unshift File.expand_path("../../lib", __FILE__)
require "gorgon"
require File.expand_path("../support/originator_handler", __FILE__)

RSpec.configure do |config|
  config.include OriginatorHandler
end
