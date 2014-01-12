# encoding: UTF-8
require 'metadata/helpers'

class TestNotePath < Minitest::Test
  def setup
    @notebook  = 'Default Notebook'
    @note_id   = 'x-cored-id//:some-stuff/124968686'
    @note_path = "#{@notebook}\n#{@note_id}"
  end

  def test_notepath_representation
    note = Metadata::Helpers::NotePath.new(@note_path)
    assert_equal @note_id,  note.id
    assert_equal @notebook, note.notebook
  end
end
