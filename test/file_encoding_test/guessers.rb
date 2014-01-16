# encoding: UTF-8
require 'file_encoding/guessers'

class TestGuessers < Minitest::Test
  def test_default_set_returns_guesser_array
    assert_respond_to  FileEncoding::Guessers, :default_set
    assert_instance_of Array, FileEncoding::Guessers.default_set
    assert_operator    FileEncoding::Guessers.default_set.count, :>=, 1
    FileEncoding::Guessers.default_set.each do |g| assert_kind_of FileEncoding::Guesser, g end
  end
end
