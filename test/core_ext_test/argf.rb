# encoding: UTF-8
require 'core_ext/argf'
require 'shellwords'

def ruby_run(cmd, *args)
  %x{ruby -I #{LIB_PATH.shellescape} -e 'require "core_ext"; #{cmd}' #{args.join(' ')}}
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
