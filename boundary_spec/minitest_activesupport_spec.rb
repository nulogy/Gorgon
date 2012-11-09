
describe "ActiveSupport with MiniTest::Unit API for rails" do
  it "run tests pragmatically" do
    load 'boundary_spec/fixtures/activesupport_test.rb'

    r = MiniTest::Unit.runner
    suite = MiniTest::Unit::TestCase.test_suites[1]
    puts "suite: #{suite.test_methods}"

    puts suite.new(:test).run r

    puts r.report
  end
end
