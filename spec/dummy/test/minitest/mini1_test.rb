require 'minitest/unit'

class GorgonMini1Test < MiniTest::Unit::TestCase
  def test_pass
    assert true
  end

  def test_that_will_be_skipped
    skip "test this later"
  end
end
