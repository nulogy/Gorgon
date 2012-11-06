require 'gorgon/mini_test_runner'

describe MiniTestRunner do
  subject {MiniTestRunner}
  it {should respond_to(:run_file).with(1).argument}
  it {should respond_to(:runner).with(0).argument}

  describe "#run_file" do

    let(:runner) {stub("MiniTestUnitRunner", :run => nil, :report => ["report"])}
    before do
      Object.stub(:load)
      MiniTestUnitRunner.stub(:new).and_return(runner)
    end

    it "loads filename" do
      Object.should_receive(:load).with("file_test.rb")
      MiniTestRunner.run_file "file_test.rb"
    end

    it "runs the MiniTestUnitRunner" do
      runner.should_receive(:run)
      MiniTestRunner.run_file "file_test.rb"
    end

    it "returns runner's report" do
      MiniTestRunner.run_file("file_test.rb").should == ["report"]
    end
  end

  describe ".runner" do
    it "returns :minitest" do
      MiniTestRunner.runner.should == :minitest
    end
  end
end
