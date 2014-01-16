# encoding: UTF-8
require 'metadata/helpers'

class TestNotePath < Minitest::Test
  def setup
    @notebook  = 'Default Notebook'
    @note_id   = 'x-cored-id//:some-stuff/124968686'
    @note_path = "#{@notebook}\n#{@note_id}"
  end

  def test_parses_note_path_input
    path = Metadata::Helpers::NotePath.new(@note_path)
    assert_equal @note_id,  path.id
    assert_equal @notebook, path.notebook

    path = Metadata::Helpers::NotePath.new(path)
    assert_equal @note_id,  path.id
    assert_equal @notebook, path.notebook
  end

  def test_to_s_returns_string_format
    path = Metadata::Helpers::NotePath.new(@note_path)
    assert_equal @note_path, path.to_s
  end
end
