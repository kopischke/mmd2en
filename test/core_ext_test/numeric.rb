# encoding: UTF-8
require 'core_ext/numeric'

class TestNumeric < Minitest::Test
  def test_exposes_scale_method
    assert_respond_to 5,    :scale
    assert_respond_to 0.35, :scale
  end

  def test_scale_raises_argument_error_if_not_passed_ranges
    assert_raises(ArgumentError) { 1.scale([1, 2], (3..4)) }
    assert_raises(ArgumentError) { 9.1.scale((3..4), 56) }
  end

  def test_scale_scales_value_to_ranges
    # parallel range progression
    assert_equal  1, -1.scale((-1..1), (1..15))
    assert_equal  8,  0.scale((-1..1), (1..15))
    assert_equal 15,  1.scale((-1..1), (1..15))

    # inverse from range progression
    assert_equal 15, -1.scale((1..-1), (1..15))
    assert_equal  8,  0.scale((1..-1), (1..15))
    assert_equal  1,  1.scale((1..-1), (1..15))

    # inverse tom range progression
    assert_equal  -10,  1.scale((-1..1), (5..-10))
    assert_equal -2.5,  0.scale((-1..1), (5..-10))
    assert_equal    5, -1.scale((-1..1), (5..-10))
  end
end
