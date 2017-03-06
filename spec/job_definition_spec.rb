require 'gorgon/job_definition'
require 'yajl'

describe Gorgon::JobDefinition do
  before(:all) do
    @json_parser = Yajl::Parser.new(:symbolize_keys => true)
  end

  describe "#to_json" do
    it "should serialize itself to json" do
      expected_hash = {
        :type => "job_definition",
        :file_queue_name => "string 1",
        :reply_exchange_name => "string 2",
        :sync => {:exclude => "string 4"},
        :callbacks => {}
      }

      jd = Gorgon::JobDefinition.new(expected_hash)

      @json_parser.parse(jd.to_json).should == expected_hash
    end
  end
end

