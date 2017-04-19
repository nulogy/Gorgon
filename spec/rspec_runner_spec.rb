require 'gorgon/rspec_runner'

describe RspecRunner do

  subject {RspecRunner}
  it {should respond_to(:run_file).with(1).argument}
  it {should respond_to(:runner).with(0).argument}

  describe "#run_file" do
    let(:configuration) { double('Configuration') }

    before do
      allow(RSpec::Core::Runner).to receive(:run)
      allow(RspecRunner).to receive(:keep_config_modules).and_yield
    end

    it "uses Rspec runner to run filename and uses the correct options" do
      expect(RSpec::Core::Runner).to receive(:run).with(["-f",
                                                         "RSpec::Core::Formatters::GorgonRspecFormatter",
                                                         "file"], anything, anything)
      RspecRunner.run_file "file"
    end

    it "passes StringIO's (or something similar) to rspec runner" do
      expect(RSpec::Core::Runner).to receive(:run).with(anything,
                                                        duck_type(:read, :write, :close),
                                                        duck_type(:read, :write, :close))
      RspecRunner.run_file "file"
    end

    it "parses the output of the Runner and returns it" do
      str_io = double("StringIO", :rewind => nil, :read => :content)
      allow(StringIO).to receive(:new).and_return(str_io)
      expect_any_instance_of(Yajl::Parser).to receive(:parse).with(:content).and_return :result
      expect(RspecRunner.run_file("file")).to eq(:result)
    end
  end

  describe "#runner" do
    it "returns :rspec" do
      expect(RspecRunner.runner).to eq(:rspec)
    end
  end
end
