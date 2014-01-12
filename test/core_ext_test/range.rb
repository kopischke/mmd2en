# encoding: UTF-8
require 'core_ext/range'

class TestRange < Minitest::Test
  def test_min_max_work_on_inverted_ranges
    assert_equal (-1..5).min, (5..-1).min
    assert_equal (-1..5).max, (5..-1).max
  end
end
