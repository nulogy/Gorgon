describe "Failing spec" do
  it "passes once" do
    expect(true).to eq(true)
  end

  it "fails" do
    expect(true).to eq(false), 'failed'
  end

  it "has pending tests"
end
