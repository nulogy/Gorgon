require 'rubygems'
require 'rspec'

RSpec.shared_examples "a shared example" do
  it "passes" do
    expect(true).to eq(true)
  end
end

RSpec.configure do |config|
  config.add_setting :custom_setting
  config.custom_setting = :set
end
