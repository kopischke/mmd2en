# encoding: UTF-8
require 'core_ext/file'
require 'tempfile'

module ContentHandling
  def reference_content(content)
    reference = case
      when content.is_a?(File)   then File.read(content)
      when content.is_a?(String) then content
      else String(content)
    end
  end
end

class TestFile < Minitest::Test
  include ContentHandling

  def setup
    @file    = File.new(__FILE__)
    @tmpfile = Tempfile.new('TEST')
    @content = [@file, 'Some string', :not_a_string]
  end

  def teardown
    @file.close
    @tmpfile.close!
  end

  def test_exposes_incremental_write_methods
    assert_respond_to File,  :incremental_write
    assert_respond_to @file, :incremental_write
  end

  def test_class_incremental_write_writes_all_content
    @content.each do |content|
      File.incremental_write(@tmpfile, content)
      assert_equal File.read(@tmpfile), reference_content(content)
    end
  end

  def test_instance_incremental_write_writes_all_content
    @content.each do |content|
      File.new(@tmpfile).incremental_write(content)
      assert_equal File.read(@tmpfile), reference_content(content)
    end
  end
end
