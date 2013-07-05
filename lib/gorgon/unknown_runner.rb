class UnknownRunner
  UNKNOWN_FRAMEWORK_MSG = "Unknown Test Framework. Gorgon only supports Test::Unit, MiniTest, and RSpec"
  def self.run_file(filename)
    raise UNKNOWN_FRAMEWORK_MSG
  end

  def self.runner
   :unknown_framework
  end
end
