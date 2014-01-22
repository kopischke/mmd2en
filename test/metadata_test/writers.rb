# encoding: UTF-8
require 'applescripter'
require 'date'
require 'edam'
require 'metadata/writers'
require 'tempfile'
require 'uri'

module TestingWriter
  class Writer < Metadata::Writer
    attr_reader :normalizers, :writers, :runner

    def initialize(*args)
      super
      @runner = Minitest::Mock.new
      @truth  = Metadata::Helpers::EvernoteRunner.new
    end

    def expect_acquire
      2.times do @runner.expect(:tell_command, @truth.tell_command) end
    end

    def expect_write(note, input, returns, ok = true)
      note_var = 'targetNote'
      command = [
        %Q{set #{note_var} to note id "#{note.id}" of notebook "#{note.notebook}"},
        %Q{tell #{note_var}},
        *@writers.fetch(@key, @writers['default']).call(input),
        %Q{end tell}
      ]
      @runner.expect :run_script, returns, [*command, get_note_path_for: note_var]
      @runner.expect :ok?, ok
    end
  end
end

class TestWriter < Minitest::Test
  include EDAM
  include TestingWriter

  def setup
    @title_sieve  = StringSieve.new(max_chars: NOTE_TITLE_LEN_MAX)
    @title_writer = Writer.new('title')
    @title_writer.sieve = @title_sieve

    @book_sieve   = StringSieve.new(max_chars: NOTEBOOK_NAME_LEN_MAX)
    @book_writer  = Writer.new('notebook')
    @book_writer.sieve = @book_sieve

    @tag_sieve    = StringSieve.new(max_chars: TAG_NAME_LEN_MAX, also_strip: ',')
    @tags_sieve   = ArraySieve.new(max_items: NOTE_TAGS_MAX)
    @tags_sieve.item_sieve =  @tag_sieve
    @tags_writer  = Writer.new('tags', type: :list)
    @tags_writer.sieve = @tags_sieve

    @files_sieve  = ArraySieve.new(max_items: NOTE_RESOURCES_MAX)
    @files_writer = Writer.new('attachments', type: :list, item_type: :file)
    @files_writer.sieve = @files_sieve

    @url_writer   = Writer.new('source url')
    @date_writer  = Writer.new('subject date',  type: :date)
    @due_writer   = Writer.new('reminder time', type: :date)

    @notebook     = 'Default Notebook'
    @note_id      = 'x-cored-id//:some-stuff/124968686'
    @note_path    = "#{@notebook}\n#{@note_id}"
    @note         = Metadata::Helpers::NotePath.new(@note_path)
    @note_var     = 'targetNote'

    # set expectations for a single `acquire` call
    @expect_acquire = ->(writer, input, object, returns) {
      acquire_command = [
        %Q{set #{assignee} to {}},
        %Q{repeat with theName in #{Array(names).to_applescript}},
        %Q{try},
        %Q{#{@runner.tell_command} to set end of #{assignee} to #{object} theName},
        %Q{on error},
        %Q{#{@runner.tell_command} to set end of #{assignee} to (make new #{object} with properties {name:theName})},
        %Q{end try},
        %Q{end repeat}
      ]
      writer.runner.expect :run_script, returns, acquire_command
      writer.runner.expect :ok?, true
    }

    # set expectations for a single `write` call
    @expect_write = ->(writer, write_command, returns, ok = true) {
      command = [
        %Q{set #{@note_var} to note id "#{@note_id}" of notebook "#{@notebook}"},
        %Q{tell #{@note_var}},
        *write_command,
        %Q{end tell}
      ]
      writer.runner.expect :run_script, returns, [*command, get_note_path_for: @note_var]
      writer.runner.expect :ok?, ok
    }

    @test_date = Date.today
    @test_str  = 'My nifty title'
    @test_url  = 'http://manual.macromates.com/'

    @long_str  = ''
    until @long_str.length > NOTE_TITLE_LEN_MAX do @long_str << ' ' << @test_str end

    @not_a_file  = '/no/such/file'
    @not_a_file << (a..z).to_a.sample while File.exist?(@not_a_file)
    @input_files = [@not_a_file, __FILE__]
    @valid_files = @input_files.select {|f| File.readable?(f) }.map {|f| Pathname.new(f) }

    @test_data = {
      @title_writer => [@long_str, @long_str, @title_sieve.strain(@long_str)],         # String   => sanitized String
      @url_writer   => [@test_url.to_sym, @test_url],                                  # Symbol   => String
      @date_writer  => [String(@test_date), @test_date],                               # String   => DateTime
      @due_writer   => [(@test_date + 15).to_datetime, (@test_date + 15).to_datetime], # Date     => Date
      @files_writer => [@input_files, @valid_files, @valid_files]                      # [String] => [valid Pathname]
    }
  end

  def test_exposes_readonly_properties
    writer = Metadata::Writer.new('test')
    [:key, :type, :item_type].each do |m|
      assert_respond_to writer, m
      refute_respond_to writer, "#{m}="
    end
  end

  def test_exposes_sieve_accessor
    writer = Metadata::Writer.new('test')
    assert_respond_to writer, :sieve
    assert_respond_to writer, :sieve=

    writer.sieve = @files_sieve
    assert_equal @files_sieve, writer.sieve
    assert writer.sieve.frozen?
    assert_raises(ArgumentError) { writer.sieve = 'Foobar' }
  end

  def test_normalizers_handle_text_input
    writer = Writer.new('text')
    [URI(@test_url), @test_str.to_sym, @test_date, rand(500)].each do |input|
      assert_equal String(input), writer.normalizers[:text].call(input)
    end
  end

  def test_normalizers_handle_date_input
    writer = Writer.new('date')
    [@test_date, String(@test_date), @test_date.to_datetime].each do |input|
      assert_equal @test_date, writer.normalizers[:date].call(input)
    end
  end

  def test_normalizers_handle_file_input
    assert_equal @valid_files, @input_files.map {|f| Writer.new('file').normalizers[:file].call(f) }.compact
  end

  def test_normalizers_handle_list_input
    # apply item normalization, compact and dedupe result
    text_writer = Writer.new('test', type: :list) # item_type: :text is default
    text_input  = [@test_str.to_sym, @test_date, URI(@test_url), @test_str, rand(500)]
    assert_equal text_input.map {|e| String(e) }.compact.uniq, text_writer.normalizers[:list].call(text_input)

    # textual input: by default, split on newline only
    assert_equal @valid_files, @files_writer.normalizers[:list].call(@input_files.join($/))
    assert_equal [],           @files_writer.normalizers[:list].call(@input_files.join(', '))

    # textual input: if an item sieve defines split characters, split on these too
    assert_equal ['foo', ' bar', 'baz'], @tags_writer.normalizers[:list].call("foo, bar,baz")
    assert_equal ['foo', 'bar', 'baz'],  @tags_writer.normalizers[:list].call("foo#{$/}bar#{$/}baz")
    assert_equal ['foo', 'bar', ' baz'], @tags_writer.normalizers[:list].call("foo#{$/}bar, baz")
  end

  def test_normalizers_raise_runtime_error_on_invalid_type
    assert_raises(RuntimeError) { Writer.new('boom').normalizers[:other].call(@test_str) }
  end

  def test_write_applies_correct_normalizer_and_eventual_sieve
    @test_data.each do |writer, content|
      # normalization
      input = writer.normalizers[writer.type].call(content[0])
      assert_equal content[1], input

      # EDAM sieve straining
      if writer.sieve
        input = writer.sieve.strain(input)
        assert_equal content[2], input
      end
    end
  end

  def test_write_writes_note_properties
    @test_data.each do |writer, content|
      raw  = content[0]
      sane = writer.normalizers[writer.type].call(raw)
      sane = writer.sieve.strain(sane) if writer.sieve

      writer.expect_write(@note, sane, @note_path)

      out = writer.write(@note, raw)
      assert_equal @note.id,       out.id
      assert_equal @note.notebook, out.notebook
      writer.runner.verify
    end
  end

  def test_write_assigns_evernote_objects
    [ {key: 'notebook', object: 'notebook', writer: @book_writer, content: 'A different notebook',
       key: 'tags',     object: 'tag',      writer: @tags_writer, content: ['foo', 'bar', 'baz']}
    ].each do |item|
      writer = item[:writer]
      raw    = item[:content]
      sane   = writer.normalizers[writer.type].call(raw)
      sane   = writer.sieve.strain(sane) if writer.sieve

      2.times do writer.expect_acquire end
      writer.expect_write(@note, sane, @note_path)

      out = writer.write(@note, raw)
      assert_equal @note.id,       out.id
      assert_equal @note.notebook, out.notebook
      writer.runner.verify
    end
  end

  def test_write_raises_runtime_error_on_applescript_error
    new_note_path = "Foo bar\n1234505685"
    input         = 'Whatever'
    err_msg       = /`osascript` command exited with code: \[1\]./

    @title_writer.expect_write(@note, input, new_note_path, false)
    @title_writer.runner.expect :exitstatus, [1]

    assert_raises(RuntimeError) { assert_equal @note.to_s, @title_writer.write(@note, input).to_s }
    @title_writer.runner.verify
  end

  def test_write_raises_runtime_error_on_validation_failing
    straining_writers = @test_data.keys.reject {|w| w.sieve.nil? }
    skip 'No writers with sieves to test.' if straining_writers.empty?
    straining_writers.each do |writer|
      assert_raises(RuntimeError)  { writer.write(@note, '') }
    end
  end
end
