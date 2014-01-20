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
  end
end
