require 'test/unit'
require 'test/unit/testresult'

Test::Unit.run = true # This stops testunit from running the file as soon as it is included. Yep. That's correct. True.

class Test::Unit::TestCase

  def self.suites
    @suites ||= []
  end

  def self.clear_suites!
    @suites = []
  end

  def self.inherited(klass)
    self.suites << klass
  end
end

class TestRunner
  def self.run_file(filename)
    Test::Unit::TestCase.clear_suites!
    load filename

    result = Test::Unit::TestResult.new
    output = []
    result.add_listener(Test::Unit::TestResult::FAULT) do |value|
      output << value
    end

    Test::Unit::TestCase.suites.each do |klass|
      klass.suite.run(result) {|s,n|;}
    end

    output
  end
end
