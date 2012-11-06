require 'minitest/unit'

class MiniTestUnitRunner < MiniTest::Unit
  def puts(*args);  end
  def print(*args); end
  def status(io = output);  end
end

class MiniTestRunner
  class << self
    def run_file(filename)
      MiniTest::Unit.runner = MiniTestUnitRunner.new
      load filename
      MiniTest::Unit.runner.run

      MiniTest::Unit.runner.report
    end

    def runner
      :minitest
    end
  end
end
