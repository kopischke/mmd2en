# encoding: UTF-8
require_relative 'test_helper'
require 'metadata'
require 'tempfile'
require 'uri'

class TestProcessorQueue < Minitest::Test
  def setup
    @queue = Metadata::ProcessorQueue.new
  end

  def test_initializes_empty
    assert_equal 0, @queue.count
  end

  def test_queues_and_dequeues_items
    count = rand(3..30)
    assert_equal true, @queue.empty?
    assert_equal 0, @queue.count

    count.times do rand(2) == 0 ? @queue << nil : @queue.push(nil) end
    assert_equal false, @queue.empty?
    assert_equal count, @queue.count

    count.times do @queue.pop end
    assert_equal true, @queue.empty?
    assert_equal 0, @queue.count
  end

  def test_exposes_item_accessor
    rand(3..30).times do |i|
      item = rand(0..1000)
      @queue << item
      assert_equal item, @queue[i]
    end
  end

  def test_is_enumerable
    count = rand(3..30)
    count.times do @queue << 0 end
    @queue.each_index do |i, _| assert_operator i, :<=, @queue.count end
    @queue.each do |v| assert_equal 0, v end
  end

  def test_compiles_metadata_from_all_processors_in_order
    Tempfile.open('TestProcessorQueue') do |file|
      proc_1 = Minitest::Mock.new
      proc_1.expect :call, {Title: 'My Title', KeyWords: ['foo', 'bar']}, [File]
      @queue << proc_1

      proc_2 = Minitest::Mock.new
      proc_2.expect :call, {'book' => 'My Book', 'title' => 'Alternate title', 'author' => 'Qi-Gong Jin'}, [File]
      @queue << proc_2

      timestamp = DateTime.now
      proc_3 = Minitest::Mock.new
      proc_3.expect :call, {'KEYWORDS' => ['baz', 'qux'], 'PUBLICATION DATE' => timestamp, author: 'Obi-Wan'}, [File]
      @queue << proc_3

      metadata = @queue.compile(file)
      assert_equal 5, metadata.count
      assert_equal 'Alternate title', metadata['title']
      assert_equal ['baz', 'qux'],    metadata['keywords']
      assert_equal 'My Book',         metadata['book']
      assert_equal 'Obi-Wan',         metadata['author']
      assert_equal timestamp,         metadata['publication date']

      proc_1.verify
      proc_2.verify
      proc_3.verify
    end
  end

  def test_warns_and_skips_processor_if_processor_error_raised
    err_msg = 'Blackboard Monitor Error'
    data_1  = {'foo' => 'bar'}
    data_2  = {'baz' => 'qux'}

    @queue << ->(_){ data_1 }
    @queue << ->(_){ raise err_msg }
    @queue << ->(_){ data_2 }

    Tempfile.open('TestProcessorQueue') do |file|
      assert_output('', err_msg << $/) {
        assert_equal data_1.merge(data_2), @queue.compile(file)
      }
    end
  end
end

class TestProcessor < Minitest::Test
  def test_creates_instance_of_shellrunner
    shell_runner = Minitest::Mock.new
    shell_runner.expect :new, self
    Metadata.stub_const(:ShellRunner, shell_runner) do
      Metadata::Processor.new
    end
    shell_runner.verify
  end
end

class TestYAMLFrontmatterProcessor < Minitest::Test
  def setup
    @metadata = {'title' => 'My great note', 'tags' => 'foo'}
    @content  = 'My Markdown content'
    @file     = Tempfile.new('YAMLFM')
    @yamlfm   = Metadata::YAMLFrontmatterProcessor.new
  end

  def teardown
    @file.close!
  end

  def test_reads_and_strips_frontmatter_if_found
    document = ['---', *@metadata.map {|k,v| "#{k}: #{v}" }, '---', @content].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal @metadata, @yamlfm.call(@file)
    assert_equal @content,  File.read(@file.path).chomp
  end

  def test_leaves_file_alone_if_no_frontmatter_found
    document = [@content, 'Some *nice* stuff here.'].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal({}, @yamlfm.call(@file))
    assert_equal document, File.read(@file.path)
  end

  def test_returns_empty_if_file_invalid
    @file.close!
    assert_equal({}, @yamlfm.call(@file))
  end
end

class TestLegacyFrontmatterProcessor < Minitest::Test
  def setup
    @metadata = {'=' => 'My notebook', '@' => 'foo'}
    @content  = 'My Markdown content'
    @file     = Tempfile.new('LegacyFM')
    @legacyfm = Metadata::LegacyFrontmatterProcessor.new
  end

  def teardown
    @file.close!
  end

  def test_converts_frontmatter_to_mmd_metadata_if_found
    document = [*@metadata.map {|k,v| "#{k} #{v}" }, '', @content].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal({}, @legacyfm.call(@file))
    assert_equal document.gsub(/^= /, 'Notebook: ').gsub(/^\@ /, 'Tags: '), File.read(@file.path)
  end

  def test_leaves_file_alone_if_no_frontmatter_found
    document = [@content, 'Some *nice* stuff here.'].join($/) << $/
    @file.write(document)
    @file.rewind
    assert_equal({}, @legacyfm.call(@file))
    assert_equal document, File.read(@file.path)
  end

  def test_raises_runtime_error_on_sed_error
    @file.close!
    e = assert_raises(RuntimeError) { assert_output('', /^.+ sed .+$/) { @legacyfm.call(@file) } }
    assert_match /`sed` exited with status [1-9][0-9]*/, e.to_s
  end
end

class TestSpotlightPropertiesProcessor < Minitest::Test
  def setup
    @file  = File.new(__FILE__)
  end

  def teardown
    @file.close
  end

  def test_retrieves_a_hash_of_values_indexed_on_keys
    keys   = {name: 'kMDItemFSName', type: 'kMDItemContentType'}
    values = Metadata::SpotlightPropertiesProcessor.new(**keys).call(@file)
    assert_instance_of Hash, values
    assert_equal keys.keys,  values.keys
  end

  def test_retrieves_and_merges_scalar_data_points
    values = Metadata::SpotlightPropertiesProcessor.new(name: 'kMDItemFSName').call(@file)
    assert_instance_of String, values[:name]
    assert_equal File.basename(@file.path), values[:name]

    values = Metadata::SpotlightPropertiesProcessor.new(type: ['kMDItemContentType', 'kMDItemKind']).call(@file)
    assert_instance_of Array, values[:type]
    assert_equal values[:type].compact.uniq.count, values[:type].count
  end

  def test_retrieves_and_merges_array_data_points
    single = Metadata::SpotlightPropertiesProcessor.new(tree: 'kMDItemContentTypeTree').call(@file)
    assert_instance_of Array, single[:tree]
    assert_equal single[:tree].compact.uniq.count, single[:tree].count

    double = Metadata::SpotlightPropertiesProcessor.new(tree: ['kMDItemContentTypeTree', 'kMDItemContentTypeTree']).call(@file)
    assert_instance_of Array, double[:tree]
    assert_equal single, double
  end
end

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

class TestWriter < Minitest::Test
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

  def setup
    require 'edam'
    require 'applescripter'

    @title_sieve  = EDAM::StringSieve.new(max_chars: EDAM::NOTE_TITLE_LEN_MAX)
    @title_writer = Writer.new('title', sieve: @title_sieve )

    @book_sieve   = EDAM::StringSieve.new(max_chars: EDAM::NOTEBOOK_NAME_LEN_MAX)
    @book_writer  = Writer.new('notebook', sieve: @book_sieve)

    @tag_sieve    = EDAM::StringSieve.new(max_chars: EDAM::TAG_NAME_LEN_MAX, strip_chars: ',')
    @tags_sieve   = EDAM::ArraySieve.new(max_items: EDAM::NOTE_TAGS_MAX, item_sieve: @tag_sieve)
    @tags_writer  = Writer.new('tags', type: :list, sieve: @tags_sieve)

    @url_writer   = Writer.new('source url')
    @date_writer  = Writer.new('subject date',  type: :date)
    @due_writer   = Writer.new('reminder time', type: :date)

    @files_sieve  = EDAM::ArraySieve.new(max_items: EDAM::NOTE_RESOURCES_MAX)
    @files_writer = Writer.new('attachments', type: :list, item_type: :file, sieve: @files_sieve)

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
    until @long_str.length > EDAM::NOTE_TITLE_LEN_MAX do @long_str << ' ' << @test_str end

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

  def test_exposes_readable_properties
    writer = Metadata::Writer.new('foo')
    [:key, :type, :item_type, :sieve].each do |m| assert_respond_to writer, m end
  end

  def test_normalizers_handle_scalar_input
    writer = Writer.new('test')

    # :text
    [URI(@test_url), @test_str.to_sym, @test_date, rand(500)].each do |input|
      assert_equal String(input), writer.normalizers[:text].call(input)
    end

    # :date
    [@test_date, String(@test_date), @test_date.to_datetime].each do |input|
      assert_equal @test_date, writer.normalizers[:date].call(input)
    end

    # :file
    assert_equal @valid_files, @input_files.map {|f| writer.normalizers[:file].call(f) }.compact

    # :other => exception
    assert_raises(RuntimeError) { writer.normalizers[:other].call(@test_str) }
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

  def test_applies_correct_normalizer_and_eventual_sieve
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

  def test_writes_note_properties
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

  def test_assigns_evernote_objects
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

  def test_warns_and_returns_input_note_on_applescript_error
    new_note_path = "Foo bar\n1234505685"
    input         = 'Whatever'
    err_msg       = /`osascript` command exited with code: \[1\]./

    @title_writer.expect_write(@note, input, new_note_path, false)
    @title_writer.runner.expect :exitstatus, [1]

    assert_output('', err_msg) { assert_equal @note, @title_writer.write(@note, input) }
    @title_writer.runner.verify
  end

  def test_warns_and_returns_input_note_on_validation_returning_nil
    # :date normalizer returns nil
    input   = 89
    err_msg = /value '#{input}' is empty after filtering./
    assert_output('', err_msg) { assert_equal @note, @date_writer.write(@note, input) }

    # @tags_writer Sieve chain returns nil
    input   = '   '
    err_msg = /value '#{input}' is empty after filtering./
    assert_output('', err_msg) { assert_equal @note, @tags_writer.write(@note, input) }
  end
end
