require 'minitest/unit'

class MiniTestUnitRunner < MiniTest::Unit
  def puts(*args);  end
  def print(*args); end
  def status(io = output);  end
end

class MiniTestRunner
  class << self
    def run_file(filename)
      forget_previous_tests
      MiniTest::Unit.runner = MiniTestUnitRunner.new
      load filename
      MiniTest::Unit.runner.run

      MiniTest::Unit.runner.report
    end

    def runner
      :minitest
    end

    private

    def forget_previous_tests
      MiniTest::Unit::TestCase.reset
    end
  end
end
