require "gorgon/unknown_runner"

describe UnknownRunner do
  subject {UnknownRunner}
  it {should respond_to(:run_file).with(1).argument}
  it {should respond_to(:runner).with(0).argument}

  describe "#run_file" do
    it "raises since we don't support this test framework" do
      expect { UnknownRunner.run_file("any_file.rb") }
        .to raise_error UnknownRunner::UNKNOWN_FRAMEWORK_MSG
    end
  end

  describe "#runner" do
    it "returns :unknown_framework" do
      expect(UnknownRunner.runner).to eq(:unknown_framework)
    end
  end
end
