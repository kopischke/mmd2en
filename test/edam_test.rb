# encoding: UTF-8
require_relative 'test_helper'
require 'edam'

class TestEDAMStringSieve < Minitest::Test
  include EDAM

  def setup
    @max_length = 12
    @min_length = 3
    @default    = StringSieve.new
    @custom     = StringSieve.new(min_chars: @min_length, max_chars: @max_length, also_strip: ';_')
    @ellipsis   = '…' # default ellipsis character
  end

  def test_exposes_readable_properties
    [:min_chars, :max_chars, :also_strip, :ellipsis].each do |m| assert_respond_to @default, m end
  end

  def test_strain_strips_leading_and_trailing_whitespace
    assert_equal 'foo bar', @default.strain("\t foo bar  \r\n  ")
    assert_equal 'foo bar', @custom.strain("\t foo bar  \r\n  ")
  end

  def test_strain_strips_invalid_characters
    assert_equal 'foobar',     @default.strain("foo\r\nbar")
    assert_equal 'foo;bar',    @default.strain("foo;bar")
    assert_equal 'foo;__;bar', @default.strain("foo;__;bar")
    assert_equal 'foobar',     @custom.strain("foo\r\nbar")
    assert_equal 'foobar',     @custom.strain("foo;bar")
    assert_equal 'foobar',     @custom.strain("foo;bar")
  end

  def test_strain_truncates_overlong_string_input_appending_ellipsis
    input    = (0..@max_length).map { ('a'..'z').to_a.sample }.join
    ellipsis = " (#{input[0..rand(3)]})"
    sieve    = StringSieve.new(max_chars: @max_length, ellipsis: ellipsis)
    assert_equal input, @default.strain(input)
    assert_equal input[0...@max_length-@ellipsis.length] << @ellipsis, @custom.strain(input)
    assert_equal input[0...@max_length-ellipsis.length] << ellipsis, sieve.strain(input)
  end

  def test_strain_rejects_strings_shorter_than_min_chars
    assert_nil @default.strain('')
    assert_nil @custom.strain((0...@min_length-1).to_a.map(&:to_s).join)
  end
end

class TestEDAMArraySieve < Minitest::Test
  include EDAM

  def setup
    @max_items = 6
    @min_items = 3
    @test_data = [1, "foo", 1.5, 'bar']
    @default   = ArraySieve.new
    @custom    = ArraySieve.new(min_items: @max_items, max_items: @max_items)
  end

  def test_exposes_readonly_properties
    [:min_items, :max_items].each do |m|
      assert_respond_to @default, m
      refute_respond_to @default, "#{m}="
    end
  end

  def test_exposes_item_sieve_accessor
    assert_respond_to @default, :item_sieve
    assert_respond_to @default, :item_sieve=

    item_sieve = StringSieve.new
    @default.item_sieve = item_sieve
    assert_equal item_sieve, @default.item_sieve
    assert       @default.item_sieve.frozen?
    assert_raises(ArgumentError) { @default.item_sieve = 'Foobar' }
  end

  def test_strain_truncates_list_input_with_element_count_above_max_items
    items = (0...@max_items).map { @test_data.sample }
    assert_equal items.count, @default.strain(items).count
    assert_equal @max_items,  @custom.strain(items).count
  end

  def test_strain_rejects_arrays_with_less_than_min_items
    assert_nil @default.strain([])
    assert_nil @custom.strain((0...@min_items-1).map{ @test_data.sample })
  end

  def test_strain_applies_the_item_sieve_to_all_elements
    items      = ['foo', 'bar;', 'bingobongo']
    item_sieve = StringSieve.new(max_chars: 6, also_strip: ';')
    list_sieve = ArraySieve.new.tap {|s| s.item_sieve = item_sieve }
    assert_equal items.map {|e| item_sieve.strain(e) }, list_sieve.strain(items)
  end
end
