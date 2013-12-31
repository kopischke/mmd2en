# encoding: UTF-8
require_relative 'test_helper'
require 'core_ext'
require "tempfile"

def ruby_run(cmd, *args)
  %x{ruby -I #{File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))} -e 'require "core_ext"; #{cmd}' #{args.join(' ')}}
end

class TestARGF < Minitest::Test
  def test_exposes_to_files_method
    assert_respond_to ARGF, :to_files
  end

  def test_to_files_returns_passed_files_and_stdin
    argf_files = [__FILE__, __FILE__]
    stdin_file = __FILE__

    out_files = ruby_run('puts ARGF.to_files', *argf_files).chomp.split($/)
    assert_equal argf_files.count, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    argf_in   = argf_files.map {|f| File.read(f) }.join
    output    = ruby_run('ARGF.to_files.each {|f| puts File.read(f.path) }', *argf_files)
    assert_equal argf_in, output

    out_files = ruby_run('puts ARGF.to_files', "< #{stdin_file}").chomp.split($/)
    assert_equal 1, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    stdin_in  = File.read(stdin_file)
    output    = ruby_run('ARGF.to_files.each {|f| puts File.read(f.path) }', '<', stdin_file)
    assert_equal stdin_in, output

    out_files = ruby_run('puts ARGF.to_files', *argf_files, '<', stdin_file).chomp.split($/)
    assert_equal argf_files.count+1, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    output    = ruby_run('ARGF.to_files.each {|f| puts File.read(f.path) }', *argf_files, '<', stdin_file)
    assert_equal argf_in << stdin_in, output
  end

  def test_to_files_rejects_invalid_files
    argf_files = ['/dev/null/nada/limbo', __FILE__]
    out_files  = ruby_run('puts ARGF.to_files', *argf_files).chomp.split($/)
    assert_equal argf_files.select {|f| File.readable?(f) }.count, out_files.count
  end

  def test_to_files_does_not_block_on_empty_stdin
    out_files = ruby_run('puts ARGF.to_files').chomp.split($/)
    assert_equal 0, out_files.count
  end
end

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

class TestFile < Minitest::Test
  def setup
    @utf16_le = File.new(File.join(File.dirname(__FILE__), 'content', 'Test-utf16le.mmd'))
    @macroman = File.new(File.join(File.dirname(__FILE__), 'content', 'Test-macroman.mmd'))
  end

  def teardown
    @utf16_le.close
    @macroman.close
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
end

class TestEncoding < Minitest::Test
  def test_exposes_find_iana_charset_method
    assert_respond_to Encoding, :find_iana_charset
  end

  def test_finds_iana_named_charsets
    assert_equal Encoding.find('macRoman'), Encoding.find_iana_charset('macintosh')
    assert_nil   Encoding.find_iana_charset('unknown-8bit')
  end
end
