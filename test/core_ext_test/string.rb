# encoding: UTF-8
require 'core_ext/string'

class TestString < Minitest::Test
  def setup
    @mark  = '.,;.!?'.chars.sample
    @base  = String.new
    @ref   = @base.dup
    @punct = "#{@base}#{@mark}"
  end

  def test_exposes_punct_methods
    assert_respond_to @base, :punct
    assert_respond_to @base, :punct!
  end

  def test_punct_appends_punctuation_mark
    assert_equal @punct, @base.punct(@mark)
    assert_equal @ref, @base
    rand(3..9).times do @base.punct!(@mark) end
    assert_equal @punct, @base
  end

  def test_punct_respects_existing_punctuation_marks
    assert_equal @punct, @punct.punct(@mark)
    assert_equal @punct, @punct.punct!(@mark)
  end

  def test_punct_defaults_to_period
    assert_equal @base << '.', @base.punct
    assert_equal @base << '.', @base.punct!

  def test_exposes_truncate_methods
    assert_respond_to @base, :truncate
    assert_respond_to @base, :truncate!
  end

  def test_truncate_truncates_to_length
    max_length = @base.length - rand(1..3)
    assert_equal max_length, @base.truncate(max_length, nil).length
    assert       @base.start_with?(@base.truncate(max_length, nil))
    assert_equal @base.truncate(max_length, nil), @base.truncate!(max_length, nil)
  end

  def test_truncate_leaves_shorter_strings_unchanged
    max_length = @base.length
    assert_equal @base, @base.truncate(max_length)
    assert_equal @base, @base.truncate!(max_length)
  end

  def test_truncate_appends_ellipsis_on_truncation
    max_length = @base.length - rand(1..3)
    assert_equal '…',        @base.truncate(max_length)[-1]
    assert_equal max_length, @base.truncate(max_length).length
    assert_equal @base.truncate(max_length), @base.truncate!(max_length)
  end

  def test_truncate_respects_ellipsis_argument
    max_length = @base.length - rand(1..3)
    ellipsis = '...'
    assert_equal ellipsis,   @base.truncate(max_length, ellipsis)[-ellipsis.length..-1]
    assert_equal max_length, @base.truncate(max_length, ellipsis).length
    assert_equal @base.truncate(max_length, ellipsis), @base.truncate!(max_length, ellipsis)
  end

  def test_truncate_raises_argument_error_if_length_too_short
    ellipsis   = '...'
    max_length = ellipsis.length - 1
    assert_raises(ArgumentError) { @base.truncate(-1) }
    assert_raises(ArgumentError) { @base.truncate(max_length, ellipsis) }
    assert_raises(ArgumentError) { @base.truncate!(-1) }
    assert_raises(ArgumentError) { @base.truncate!(max_length, ellipsis) }
  end
end
