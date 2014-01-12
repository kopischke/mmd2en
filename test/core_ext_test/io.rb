# encoding: UTF-8
require 'core_ext/io'
require 'tempfile'
require 'time'

class TestIO < Minitest::Test
  def setup
    @r, @w = IO.pipe
    @content = "Some output\non two lines"
  end

  def teardown
    @r.close unless @r.closed?
    @w.close unless @w.closed?
  end

  def test_exposes_dump_methods
    assert_respond_to STDIN, :dump
    assert_respond_to STDIN, :dump!
  end

  def test_dump_dumps_contents_to_file_without_closing
    Thread.new { @w.puts @content; @w.close }
    assert_equal @content, File.read(@r.dump.path).chomp
    assert_equal false, @r.closed?
  end

  def test_dump_bang_dumps_contents_to_file_and_closes_stream
    Thread.new { @w.puts @content; @w.close }
    assert_equal @content, File.read(@r.dump!.path).chomp
    assert_equal true, @r.closed?
  end

  def test_dump_passes_options_to_tempfile
    kwargs   = {external_encoding: Encoding::UTF_16LE}
    tempfile = Minitest::Mock.new
    tempfile.expect :new, Tempfile.new('TEST'), [String, kwargs]
    Thread.new { @w.puts @content; @w.close }
    IO.stub_const(:Tempfile, tempfile) do
      @r.dump!(**kwargs)
      tempfile.verify
    end
  end

  def test_read_blocking_returns_true_on_blocking_io
    require 'time'
    start_time  = Time.now
    sleep_delay = 30
    Thread.new { sleep sleep_delay; @w.close }
    assert_equal    true, @r.read_blocking?
    assert_operator Time.now - start_time, :<, sleep_delay
  end

  def test_read_blocking_returns_false_on_non_blocking_io
    file = File.new(__FILE__)
    assert_equal false, file.read_blocking?
  rescue => e
    file.close
    raise e
  end
end
