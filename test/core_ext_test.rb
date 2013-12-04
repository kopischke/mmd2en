# encoding: UTF-8
require_relative 'test_helper'
require 'core_ext'

class TestARGF < Minitest::Test
  def setup
    @lib     = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
    @require = 'require "core_ext"'
  end

  def test_exposes_to_files_method
    assert_respond_to ARGF, :to_files
  end

  def test_returns_passed_files_and_stdin
    argf_files = [__FILE__, __FILE__]
    stdin_file = __FILE__

    out_files = %x{ruby -I #{@lib} -e '#{@require}; puts ARGF.to_files' #{argf_files.join(' ')}}.chomp.split($/)
    assert_equal argf_files.count, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    argf_in = argf_files.map {|f| File.read(f) }.join
    output  = %x{ruby -I #{@lib} -e '#{@require}; ARGF.to_files.each {|f| puts File.read(f.path) }' #{argf_files.join(' ')}}
    assert_equal argf_in, output

    out_files = %x{ruby -I #{@lib} -e '#{@require}; puts ARGF.to_files' < #{stdin_file}}.chomp.split($/)
    assert_equal 1, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    stdin_in = File.read(stdin_file)
    output   = %x{ruby -I #{@lib} -e '#{@require}; ARGF.to_files.each {|f| puts File.read(f.path) }' < #{stdin_file}}
    assert_equal stdin_in, output

    out_files = %x{ruby -I #{@lib} -e '#{@require}; puts ARGF.to_files' #{argf_files.join(' ')} < #{stdin_file}}.chomp.split($/)
    assert_equal argf_files.count+1, out_files.count
    assert out_files.all? {|f| f.match(/#<File:(.+)>/) }, "Output does not entirely consist of File objects."

    output = %x{ruby -I #{@lib} -e '#{@require}; ARGF.to_files.each {|f| puts File.read(f.path) }' #{argf_files.join(' ')} < #{stdin_file}}
    assert_equal argf_in << stdin_in, output
  end

  def test_rejects_invalid_files
    argf_files = ['/dev/null/nada/limbo', __FILE__]
    out_files = %x{ruby -I #{@lib} -e '#{@require}; puts ARGF.to_files' #{argf_files.join(' ')}}.chomp.split($/)
    assert_equal argf_files.select {|f| File.readable?(f) }.count, out_files.count
  end

  def test_does_not_block_on_empty_stdin
    out_files = %x{ruby -I #{@lib} -e '#{@require}; puts ARGF.to_files'}.chomp.split($/)
    assert_equal 0, out_files.count
  end
end

class TestIO < Minitest::Test
  def setup
    @content = "Some output\non two lines"
    @lib     = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
    @require = 'require "core_ext"'
  end

  def test_exposes_dump_methods
    assert_respond_to STDIN, :dump
    assert_respond_to STDIN, :dump!
  end

  def test_dumps_contents_to_file_without_closing
    dumped = %x{echo "#{@content}" | ruby -I #{@lib} -e '#{@require}; f = ARGF.file.dump; puts File.read(f.path)' }.chomp
    assert_equal @content, dumped
    open   = %x{echo "#{@content}" | ruby -I #{@lib} -e '#{@require}; f = ARGF.file.dump; puts ARGF.file.closed?' }.chomp
    assert_equal String(false), open
  end

  def test_dumps_contents_to_file_and_closes_stream
    dumped = %x{echo "#{@content}" | ruby -I #{@lib} -e '#{@require}; f = ARGF.file.dump!; puts File.read(f.path)' }.chomp
    assert_equal @content, dumped
    open   = %x{echo "#{@content}" | ruby -I #{@lib} -e '#{@require}; f = ARGF.file.dump!; puts ARGF.file.closed?' }.chomp
    assert_equal String(true), open
  end

  def test_does_not_block_on_empty_stream
    output = "And we have: "
    dumped = %x{ruby -I lib -e '#{@require}; f = ARGF.file.dump; puts "#{output}" << String(f)' }.chomp
    assert_equal output, dumped
  end
end
