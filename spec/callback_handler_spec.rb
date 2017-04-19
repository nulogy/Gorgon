require 'gorgon'

describe Gorgon::CallbackHandler do

  let(:config) {
    {
      :callbacks_class_file => "callback_file.rb"
    }
  }
  before do
    allow_any_instance_of(Gorgon::CallbackHandler).to receive(:load)
  end

  it "loads callback file" do
    allow_any_instance_of(Gorgon::CallbackHandler).to receive(:load).with config[:callbacks_class_file]

    Gorgon::CallbackHandler.new(config)
  end

  it "does not load callback file if it's not specified" do
    expect_any_instance_of(Gorgon::CallbackHandler).not_to receive(:load)

    Gorgon::CallbackHandler.new({})
  end

  context "#before_originate" do
    it "returns value from callbacks#before_originate if it's a string" do
      handler = Gorgon::CallbackHandler.new(config)
      allow(Gorgon.callbacks).to receive(:before_originate).and_return('my_job_id')
      expect(handler.before_originate).to eq('my_job_id')
    end

    it "returns nil if callbacks#before_originate did not return a string" do
      handler = Gorgon::CallbackHandler.new(config)
      allow(Gorgon.callbacks).to receive(:before_originate).and_return(Object.new)
      expect(handler.before_originate).to eq(nil)
    end
  end
end
