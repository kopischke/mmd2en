# encoding: UTF-8
require_relative 'test_helper'
require 'file_encoding'

Dir.glob(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), '*.rb')).each do |f| load f end

module Stubs
  include FileEncoding

  class StubGuesser < Guesser
    def initialize(guess)
      @_guess     = guess
    end

    def available?
      true
    end

    def guess(*_)
      @_guess
    end
  end
end

class TestFileEncoding < Minitest::Test
  include FileEncoding
  include Stubs

  def setup
    @guesses = [].fill(0..9) {|i| Guess.new(Encoding.list[i], i * 0.1) }
    @best    = @guesses.max_by {|g| g.confidence }.encoding
    @guesser = @guesses.map  {|g| StubGuesser.new(g) }
  end

  def test_guess_encoding_added_to_file_class
    assert_respond_to File,  :guess_encoding
    File.open(__FILE__) do |file|
      assert_respond_to file, :guess_encoding
    end
  end

  def test_guess_encoding_returns_encoding_with_highest_confidence
    guesser = @guesser.shuffle
    guess   = File.guess_encoding(__FILE__, *guesser)
    assert_equal @best, guess
  end

  def test_guess_encoding_stops_testing_on_full_confidence
    in_chain = @guesses.map(&:encoding)
    shortcut = Guess.new(Encoding.list.find {|e| !in_chain.include?(e) }, 1.0)
    guesser  = @guesser
    guesser.unshift(StubGuesser.new(shortcut))
    guess    = File.guess_encoding(__FILE__, *guesser)
    assert_equal shortcut.encoding, guess
  end

  def test_guess_encoding_aggregates_confidence_of_same_guesses
    # two different guesses with confidence 0.5, three identical ones with confidence 0.15 each
    encoding = Encoding.list.last
    guesses  = [].fill(0..5) {|i| i.even? ? Guess.new(Encoding.list[i], 0.5) : Guess.new(encoding, 0.25) }
    guesser  = guesses.map   {|g| StubGuesser.new(g) }
    assert_equal encoding, File.guess_encoding(__FILE__, *guesser)
  end

  def test_guess_encoding_returns_first_of_equal_guesses
    guesses = [].fill(0..2) {|i| Guess.new(Encoding.list[i], 0.5) }
    guesser = guesses.map   {|g| StubGuesser.new(g) }
    assert_equal guesses.first.encoding, File.guess_encoding(__FILE__, *guesser)
  end

  def test_guess_encoding_returns_nil_if_no_encoding_found
    nada = StubGuesser.new(nil)
    assert_nil File.guess_encoding(__FILE__, nada)
  end

  def test_guess_encoding_respects_with_dummies_option
    dummies = Encoding.list.select {|e| e.dummy? }
    good    = Encoding.list.reject {|e| e.dummy? }
    guesses = [].fill(1..5) {|i| i.even? ? Guess.new(dummies[i], 0.75) : Guess.new(good[i], 0.5) }
    guesser = guesses.map {|g| StubGuesser.new(g) }
    assert File.guess_encoding(__FILE__, *guesser).dummy? # defaults to true
    assert File.guess_encoding(__FILE__, *guesser, with_dummies: true).dummy?
    refute File.guess_encoding(__FILE__, *guesser, with_dummies: false).dummy?
  end

  def test_guess_encoding_respects_never_mind_option
    threshold = 0.3
    guesser   = StubGuesser.new(Guess.new(__ENCODING__, threshold))
    assert_equal __ENCODING__, File.guess_encoding(__FILE__, guesser) # defaults to 0.1
    assert_equal __ENCODING__, File.guess_encoding(__FILE__, guesser, never_mind: threshold - 0.1)
    assert_equal __ENCODING__, File.guess_encoding(__FILE__, guesser, never_mind: threshold)
    assert_nil   File.guess_encoding(__FILE__, guesser, never_mind: threshold + 0.1)
  end
end
