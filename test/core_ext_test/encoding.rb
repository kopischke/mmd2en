# encoding: UTF-8
require 'core_ext/encoding'

class TestEncoding < Minitest::Test
  def test_exposes_find_iana_charset_method
    assert_respond_to Encoding, :find_iana_charset
  end

  def test_finds_iana_named_charsets
    assert_equal Encoding.find('macRoman'), Encoding.find_iana_charset('macintosh')
    assert_nil   Encoding.find_iana_charset('unknown-8bit')
  end
end
