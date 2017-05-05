require "open4"
require "socket"
require File.expand_path("../support/end_to_end_helpers", __FILE__)

describe "EndToEnd" do
  include Gorgon::EndToEndHelpers

  HOSTNAME = Socket.gethostname

  before(:all) do
    Dir.chdir(File.join(__dir__, "..", "tests", "end_to_end")) do
      pid, stdin, stdout, stderr = Open4::popen4("bundle exec gorgon")
      @outputs = stdout.read.split("*" * 80)
    end
  end

  context "number of output hunks" do
    it "is same as errors raised plus meta information" do
      expect(@outputs.count).to eq(7), "expected 7 output hunks, got:\n#{@outputs.inspect}"
    end
  end

  context "meta suite run information" do
    it "has version and legend information" do
        expected_meta = <<-META
Welcome to Gorgon #{Gorgon::VERSION}
before job starts was called
Loading environment and workers...\r                                  \rLegend:
F - failure files count
H - number of hosts that have run files
W - number of workers running files


Progress: ||

        META
        expect(@outputs[0]).to eq(expected_meta)
    end
  end

  context "last hunk" do
    it "has information for running after_job_finishes callback" do
      expect(@outputs.last).to match(Gorgon::EndToEndHelpers::AFTER_RUNNING_REGEX)
    end
  end

  context "exception test" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /Stuff::Haha1/)
      expected_output = <<-EXPECTED

File 'test/unit/exception_test.rb' failed/crashed at '#{HOSTNAME}:1'
Error:
test_going_to_blow_up(Stuff::Haha1):
RuntimeError: oh mah gawd
    test/unit/exception_test.rb:10:in `test_going_to_blow_up'

      EXPECTED

      expect(actual_output).to eq(expected_output)
    end
  end

  context "exception spec" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /exception_spec/)
      expected_output = <<-EXPECTED

File 'spec/exception_spec.rb' failed/crashed at '#{HOSTNAME}:1'
Test name: Exception spec raises: line 2
RuntimeError
Message: 
	BOOOOM from spec!


      EXPECTED

      expect(actual_output).to eq(expected_output)
    end
  end

  context "syntax error test" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /1_syntax_error_test/, strip_backtrace: true)
      expected_output = <<-EXPECTED

File 'test/unit/1_syntax_error_test.rb' failed/crashed at '#{HOSTNAME}:1'
Exception: test/unit/1_syntax_error_test.rb:9: syntax error, unexpected end-of-input, expecting keyword_end

      EXPECTED
      expect(actual_output).to eq(expected_output)
    end
  end

  context "syntax error spec" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /1_syntax_error_spec/, strip_backtrace: true)
      expected_output = <<-EXPECTED

File 'spec/1_syntax_error_spec.rb' failed/crashed at '#{HOSTNAME}:1'
Exception: undefined local variable or method `ruby' for main:Object

      EXPECTED
      expect(actual_output).to eq(expected_output)
    end
  end

  context "failing test" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /failing_test\.rb/)
      expected_output = <<-EXPECTED

File 'test/unit/failing_test.rb' failed/crashed at '#{HOSTNAME}:1'
Failure:
test_2_will_fail(Stuff::Over9000) [test/unit/failing_test.rb:14]:
<false> is not true.
Failure:
test_will_fail(Stuff::Over9000) [test/unit/failing_test.rb:10]:
<false> is not true.

      EXPECTED
      expect(actual_output).to eq(expected_output)
    end
  end

  context "failing spec" do
    it "has proper error output" do
      actual_output = extract_hunk(@outputs, /failing_spec\.rb/)
      expected_output = <<-EXPECTED

File 'spec/failing_spec.rb' failed/crashed at '#{HOSTNAME}:1'
Test name: Failing spec fails: line 6
RSpec::Expectations::ExpectationNotMetError
Message: 
	failed


      EXPECTED
      expect(actual_output).to eq(expected_output)
    end
  end
end
