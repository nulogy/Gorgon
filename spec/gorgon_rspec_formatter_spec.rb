require 'gorgon/gorgon_rspec_formatter'

BaseFormatter = RSpec::Core::Formatters::GorgonRspecFormatter

describe RSpec::Core::Formatters::GorgonRspecFormatter do
  let(:example) {double("Example", :description => "description",
                      :full_description => "Full_Description",
                      :metadata => {:file_path => "path/to/file", :line_number => 2},
                      :execution_result => {:status => "passed"}, :exception => nil)}
  let(:fail_example) {double("Example", :description => "description",
                           :full_description => "Full_Description",
                           :metadata => {:file_path => "path/to/file", :line_number => 2},
                           :execution_result => {:status => "failed"}, :exception => nil)}

  let(:exception) { double("Exception", :class => Object, :message => "some msg",
                         :backtrace => "backtrace")}

  let(:output) { double("StringIO", :write => nil, :close => nil) }

  before do
    @formatter = BaseFormatter.new(output)
  end

  it "returns an array of hashes when there are failures" do
    allow(@formatter).to receive(:examples).and_return([example, fail_example])

    expected_result = [{:test_name => "Full_Description: line 2", :description => "description",
                         :full_description => "Full_Description", :status => "failed",
                         :file_path => "path/to/file", :line_number => 2}]
    expect(output).to receive(:write).with(expected_result.to_json)
    @formatter.stop
    @formatter.close
  end

  it "returns an empty array when all examples pass" do
    allow(@formatter).to receive(:examples).and_return([example, example])

    expect(output).to receive(:write).with("[]")
    @formatter.stop
    @formatter.close
  end

  it "returns an empty array when all examples are pending" do
    allow(example).to receive(:execution_result).and_return(:status => "pending")
    allow(@formatter).to receive(:examples).and_return([example, example])

    expect(output).to receive(:write).with("[]")
    @formatter.stop
    @formatter.close
  end

  it "returns exception details if there is an exception" do
    allow(fail_example).to receive(:exception).and_return(exception)
    allow(@formatter).to receive(:examples).and_return([fail_example])
    expected_result = [{:test_name => "Full_Description: line 2", :description => "description",
                         :full_description => "Full_Description", :status => "failed",
                         :file_path => "path/to/file", :line_number => 2, :class => Object.name,
                         :message => "some msg", :location => "backtrace"}]
    expect(output).to receive(:write).with(expected_result.to_json)
    @formatter.stop
    @formatter.close
  end

  it "uses RSpec 3 API when available" do
    expect(fail_example.execution_result).to receive(:status).and_return(:failed)
    notification = double(examples: [fail_example])

    expected_result = [{:test_name => "Full_Description: line 2", :description => "description",
        :full_description => "Full_Description", :status => "failed",
        :file_path => "path/to/file", :line_number => 2}]
    expect(output).to receive(:write).with(expected_result.to_json)
    @formatter.stop(notification)
    @formatter.close
  end
end
