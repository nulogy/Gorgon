require 'gorgon/job_definition'
require 'yajl'

describe JobDefinition do
  before(:all) do
    @json_parser = Yajl::Parser.new(:symbolize_keys => true)
  end

  describe "#to_json" do
    it "should serialize itself to json" do
      expected_hash = {:file_queue_name => "string 1", :reply_exchange_name => "string 2", :source_tree_path => "string 3", :callbacks => {}}

      jd = JobDefinition.new(expected_hash)

      @json_parser.parse(jd.to_json).should == expected_hash 
    end
  end
end

