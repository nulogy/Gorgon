require 'test/unit'

module Stuff
class Over9000 < Test::Unit::TestCase
  def test_blahblah
    assert true
  end

  def test_will_fail
    sleep 3
    assert false
  end
end
end

