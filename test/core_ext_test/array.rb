# encoding: UTF-8
require 'core_ext/array'

class TestArray < Minitest::Test
  def test_exposes_squash_method
    assert_respond_to [], :squash
  end

  def test_squash_returns_first_element_on_single_item_array
    val = rand(1..100)
    assert_equal val, [val].squash
  end

  def test_squash_flattens_multi_item_array
    ar = [[rand(1..100), rand(1..100)], [rand(1..100), rand(1..100), rand(1..100)], rand(1..100)]
    assert_equal ar.flatten, ar.squash
  end
end
