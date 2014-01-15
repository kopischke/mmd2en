# encoding: UTF-8
require 'core_ext/file'
require 'pathname'

class TestFile < Minitest::Test
  def setup
    path  = File.expand_path(__FILE__) == __FILE__ ? Pathname.new(__FILE__).relative_path_from(Dir.pwd).to_s : __FILE__
    @file = File.new(path)
  end

  def teardown
    @file.close
  end

  def test_exposes_real_encoding_methods
    assert_respond_to File,      :real_encoding
    assert_respond_to @utf16_le, :real_encoding
  end

  def test_real_encoding_recognizes_encodings
    assert_equal Encoding::UTF_16LE, File.real_encoding(@utf16_le.path)
    assert_equal Encoding::UTF_16LE, @utf16_le.real_encoding
    assert_equal Encoding.find('macRoman'), File.real_encoding(@macroman.path)
    assert_equal Encoding.find('macRoman'), @macroman.real_encoding
  end

  def test_real_encoding_returns_nil_when_unsure
    # Mac Roman is not recognized without the xattr, which we lose on dumping
    assert_nil File.real_encoding(@macroman.dump.path)
    assert_nil @macroman.dump.real_encoding
  end

  def test_real_encoding_respects_accept_dummy_option
    file = @macroman.dump # anything but an UTF file, which `file` recognizes
    %x{xattr -w com.apple.TextEncoding 'utf-7;0' #{file.path.shellescape}}
    assert_nil   file.real_encoding(accept_dummy: false)
    assert_equal Encoding.find('UTF-7'), file.real_encoding(accept_dummy: true)
  end

  def test_exposes_expanded_path_method
    assert_respond_to @file, :expanded_path
  end

  def test_expanded_path_returns_expanded_creation_path
    assert_equal File.expand_path(@file.path), @file.expanded_path
  end
end
