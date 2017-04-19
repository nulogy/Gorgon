require 'gorgon/mini_test_runner'

describe MiniTestRunner do
  subject {MiniTestRunner}
  it {should respond_to(:run_file).with(1).argument}
  it {should respond_to(:runner).with(0).argument}

  describe "#run_file" do

    let(:runner) {double("MiniTestUnitRunner", :run => nil, :report => ["report"])}
    before do
      allow(Object).to receive(:load)
      allow(MiniTestUnitRunner).to receive(:new).and_return(runner)
    end

    it "clear test cases previously loaded (when a previous file was loaded), and then loads filename" do
      expect(MiniTest::Unit::TestCase).to receive(:reset).ordered
      expect(Object).to receive(:load).with("file_test.rb").ordered
      MiniTestRunner.run_file "file_test.rb"
    end

    it "runs the MiniTestUnitRunner" do
      expect(runner).to receive(:run)
      MiniTestRunner.run_file "file_test.rb"
    end

    it "returns runner's report" do
      expect(MiniTestRunner.run_file("file_test.rb")).to eq(["report"])
    end
  end

  describe ".runner" do
    it "returns :minitest" do
      expect(MiniTestRunner.runner).to eq(:minitest)
    end
  end
end
