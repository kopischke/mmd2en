# encoding: UTF-8
require 'file_encoding/guesser'
require 'file_encoding/queue'

class StubGuesser < FileEncoding::Guesser
  def initialize(guess, available = true)
    @guess     = guess
    @available = available
  end

  def available?
    @available
  end

  def guess(*_)
    @guess
  end
end

class TestGuesserQueue < Minitest::Test
  include FileEncoding
  def setup
    @default_set = Guessers.default_set
    @available   = @default_set.select {|e| e.available? }
    @full_queue  = GuesserQueue.new(*@default_set)

    @confidence  = 0.35
    @dummy_enc   = Encoding.list.find {|e| e.dummy? }
    @dummy_guess = Guess.new(@dummy_enc, @confidence)
  end

  def test_exposes_available_guessers_reader
    assert_respond_to @full_queue, :available_guessers
    refute_respond_to @full_queue, :available_guessers=
    assert_equal @available, @full_queue.available_guessers
  end

  def test_exposes_delegated_methods
    [:[], :<<, :push, :pop, :count, :length, :empty?, :each, :each_index].each do |method|
      assert_respond_to @full_queue, method
    end
  end

  def test_enqueues_all_passed_guessers_in_order
    assert_equal @default_set.count, @full_queue.count
    @default_set.each.with_index do |g,i| assert_equal g, @full_queue[i] end
  end

  def test_returns_encoding_with_highest_confidence
    encoding = Encoding.list.find {|e| !e.dummy? }
    ignore   = StubGuesser.new(@dummy_guess)
    match    = StubGuesser.new(Guess.new(encoding, @confidence * 2))
    [[ignore, match], [match, ignore]].each do |guessers|
      assert_equal encoding, GuesserQueue.new(*guessers).process(__FILE__)
    end
  end

  def test_aggregates_confidence_of_same_guess
    first  = StubGuesser.new(Guess.new(__ENCODING__, @confidence))
    second = StubGuesser.new(Guess.new(__ENCODING__, @confidence))
    queue  = GuesserQueue.new(first, second, stop_threshold: @confidence * 2)
    assert_equal __ENCODING__, queue.process(__FILE__)
    queue  = GuesserQueue.new(first, second, reject_threshold: @confidence * 2)
    assert_equal __ENCODING__, queue.process(__FILE__)
  end

  def test_returns_nil_if_no_encoding_found
    assert_nil GuesserQueue.new(StubGuesser.new(nil)).process(__FILE__)
  end

  def test_respects_accept_dummy_option
    assert_nil GuesserQueue.new(StubGuesser.new(@dummy_guess), accept_dummy: false).process(__FILE__)
  end

  def test_respects_stop_threshold_option
    match = StubGuesser.new(@dummy_guess)
    other = StubGuesser.new(Guess.new(__ENCODING__, @confidence * 2))
    queue = GuesserQueue.new(match, other, stop_threshold: @confidence)
    assert_equal @dummy_guess.encoding, queue.process(__FILE__)
  end

  def test_respects_reject_threshold_option
    assert_nil GuesserQueue.new(StubGuesser.new(@dummy_guess), reject_threshold: @confidence + 0.1).process(__FILE__)
  end
end