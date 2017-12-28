RSpec.describe "Keeping rspec configuration" do
  it "keeps rspec configuration" do
    expect(RSpec.configuration.custom_setting).to eq(:set)
  end
end
