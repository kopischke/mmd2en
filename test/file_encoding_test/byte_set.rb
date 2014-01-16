# encoding: UTF-8
require 'file_encoding/byte_set'
require 'tempfile'

class TestByteSet < Minitest::Test
  def setup
    @file   = Tempfile.new('TEST', binmode: true)
    @bytes  = [0xe0, 0xef, 0xf0, 0xf7]
    @repeat = 5
    @repeat.times do
      @bytes.each do |byte| @file.write(byte.chr) end
    end
    @file.flush
    @byte_set = FileEncoding::ByteSet.new(@file)
  end

  def teardown
    @file.close
  end

  def test_exposes_file_reader
    assert_respond_to @byte_set, :file
    refute_respond_to @byte_set, :file=
    assert_equal      @file.path, @byte_set.file.path
  end

  def test_exposes_count_reader
    assert_respond_to @byte_set, :count
    refute_respond_to @byte_set, :count=
    assert_equal      @bytes.count * @repeat, @byte_set.count
  end

  def test_exposes_chunk_size_reader
    assert_respond_to @byte_set, :chunk_size
    refute_respond_to @byte_set, :chunk_size=
    assert_nil        @byte_set.chunk_size
  end

  def test_first_method_returns_first_byte
    assert_respond_to @byte_set, :first
    assert_equal      @bytes.first, @byte_set.first
  end

  def test_starts_with_method_matches_starting_bytes
    assert_respond_to @byte_set, :start_with?
    assert_respond_to @byte_set, :starts_with?
    assert_equal      true, @byte_set.starts_with?(*@bytes)
    assert_equal      true, @byte_set.starts_with?(*@bytes[0..2], @bytes)
    refute_equal      true, @byte_set.starts_with?(*@bytes[0..2], 0xff)
    refute_equal      true, @byte_set.starts_with?(*@bytes[0..2], @bytes.reject {|b| b == @bytes[3]})
  end

  def test_count_of_method_returns_total_count_of_specific_bytes
    count = (2..4).to_a.sample
    assert_respond_to @byte_set, :count_of
    @bytes.each do |b| assert_equal @repeat, @byte_set.count_of(b) end
    assert_equal count * @repeat, @byte_set.count_of(@bytes.sample(count))
  end

  def test_ratio_of_method_returns_ratio_of_specific_bytes_to_total
    count = (2..4).to_a.sample
    assert_respond_to @byte_set, :ratio_of
    @bytes.each do |b| assert_equal 1.0 / @bytes.count, @byte_set.ratio_of(b) end
    assert_equal 1.0 / @bytes.count * count, @byte_set.ratio_of(@bytes.sample(count))
  end

  def test_respects_chunk_size
    chunks     = (1..@repeat-1).to_a.sample
    chunk_size = @bytes.count * chunks
    byte_set   = FileEncoding::ByteSet.new(@file, chunk_size)
    assert_equal chunk_size, byte_set.count
    assert_equal chunk_size, byte_set.chunk_size
    @bytes.each do |b| assert_equal chunks, byte_set.count_of(b) end
  end
end
