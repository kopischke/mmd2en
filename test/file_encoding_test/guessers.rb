# encoding: UTF-8
require 'file_encoding/guessers'

class TestGuessers < Minitest::Test
  include FileEncoding

  def test_default_set_returns_guesser_array
    assert_respond_to  Guessers, :default_set
    assert_instance_of Array, Guessers.default_set
    assert_operator    Guessers.default_set.count, :>=, 1
    Guessers.default_set.each do |g| assert_kind_of Guesser, g end
  end

  def test_provided_guessers_return_a_guess_or_nil
    guessers = [
        Guessers::Cheap,
        Guessers::Expensive,
        Guessers::Platform
      ].flat_map {|mod|
        mod.constants.map {|c| mod.const_get(c, false) }
      }.select   {|guesser|
        guesser.is_a?(Guesser)
      }
    skip 'No Guesser implementations found.' if guessers.empty?
    guessers.each do |g|
      guess = g.guess(__FILE__)
      assert_instance_of Guess, guess unless guess.nil?
    end
  end
end
