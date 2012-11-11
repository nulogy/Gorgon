require 'test/unit'
require 'test/unit/testresult'

Test::Unit.run = true # This stops testunit from running the file as soon as it is included. Yep. That's correct. True.

module GorgonTestCases
  def self.cases
    @gorgon_cases ||= []
  end

  def self.clear_cases!
    @gorgon_cases = []
  end
end


if defined? ActiveSupport::TestCase
  class ActiveSupport::TestCase
    def self.inherited(klass)
      GorgonTestCases.cases << klass
    end
  end
end

class Test::Unit::TestCase
  def self.inherited(klass)
    GorgonTestCases.cases << klass
  end
end

class TestUnitRunner
  def self.run_file(filename)
    GorgonTestCases.clear_cases!
    load filename

    result = Test::Unit::TestResult.new
    output = []
    result.add_listener(Test::Unit::TestResult::FAULT) do |value|
      output << value
    end

    GorgonTestCases.cases.each do |klass|
      # Not all descendants of TestCase are actually runnable, but they do all implement #suite
      # Calling suite.run will give us only runnable tests
      klass.suite.run(result) {|s,n|;}
    end

    output
  end

  def self.runner
    :test_unit
  end
end
