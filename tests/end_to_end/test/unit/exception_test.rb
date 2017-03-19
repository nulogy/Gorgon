require 'test/unit'

module Stuff
  class Haha1 < Test::Unit::TestCase
    def test_blahblah
      assert true
    end

    def test_going_to_blow_up
      raise "oh mah gawd"
    end
  end
end

