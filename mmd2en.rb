# encoding: UTF-8
require 'rexml/document'
require 'tempfile'

require_relative 'lib/applescripter'
require_relative 'lib/core_ext'
require_relative 'lib/edam'
require_relative 'lib/metadata'
require_relative 'lib/mmd'

MASTER_ENCODING = Encoding::UTF_8

# Acquire sources:
encoding = [Encoding.default_external.name.gsub(/^(?=UTF-)/i, 'BOM|'), MASTER_ENCODING.name].join(':')
sources  = ARGF.to_files(encoding: encoding)
sources.empty? and exit

# Set up MMD parser and Tempfile key:
mmd = MultiMarkdownParser.new
TMP = 'mmd2en'

# Create the file system metadata processor queue:
file_queue    =  Metadata::ProcessorQueue.new
file_queue    << Metadata::FilePropertiesProcessor.new(date: :ctime)
file_queue    << Metadata::SpotlightPropertiesProcessor.new(tags: ['kMDItemUserTags', 'kMDItemOMUserTags'])

# Create the content metadata source processor queue:
content_queue =  Metadata::ProcessorQueue.new
content_queue << Metadata::YAMLFrontmatterProcessor.new
content_queue << Metadata::LegacyFrontmatterProcessor.new
content_queue << ->(file) { mmd.load_file_metadata(file, 'title', 'notebook', 'tags', 'keywords', 'url') }

# Set up Evernote metadata item specific writers:
title_sieve  = EDAM::StringSieve.new(max_chars: EDAM::NOTE_TITLE_LEN_MAX)
title_writer = Metadata::Writer.new('title', sieve: title_sieve )

book_sieve   = EDAM::StringSieve.new(max_chars: EDAM::NOTEBOOK_NAME_LEN_MAX)
book_writer  = Metadata::Writer.new('notebook', sieve: book_sieve)

tag_sieve    = EDAM::StringSieve.new(max_chars: EDAM::TAG_NAME_LEN_MAX, strip_chars: ',')
tags_sieve   = EDAM::ArraySieve.new(max_items: EDAM::NOTE_TAGS_MAX, item_sieve: tag_sieve)
tags_writer  = Metadata::Writer.new('tags', type: :list, sieve: tags_sieve)

url_writer   = Metadata::Writer.new('source url')
date_writer  = Metadata::Writer.new('subject date',  type: :date)
due_writer   = Metadata::Writer.new('reminder time', type: :date)

files_sieve  = EDAM::ArraySieve.new(max_items: EDAM::NOTE_RESOURCES_MAX)
files_writer = Metadata::Writer.new('attachments', type: :list, item_type: :file, sieve: files_sieve)

# Map found metadata keys to writers:
writers = {
  /^title$/i                                    => title_writer,
  /^(notebook|category)$/i                      => book_writer,
  /^(key ?words|tag(s|ged)|categories)$/i       => tags_writer,
  /^((source )?url|(perma)?link)$/i             => url_writer,
  /^((pub(lication )?)?date|published( on)?)$/i => date_writer,
  /^(due|remind(er| me)?)( on)?$/i              => due_writer,
  /^attach(ments|ed( (documents|files))?)?$/i   => files_writer
}

sources.each do |source|
  filename = nil
  metadata = {}

  # Get merged file system metadata from the original files:
  unless source.is_a?(Tempfile)
    metadata = file_queue.compile(source)
    filename = File.basename(source, '.*')
  end

  # Skip files / streams with unknown encoding, as we cannot ensure conversion to UTF-8:
  # accept Rubys’s BOM recognition (which results in pos > 0), else check externally.
  unless source.pos > 0 || source_encoding = source.real_encoding(accept_dummy: false)
    warn "Skipping #{filename ? "file '#{source.path}'" : 'input stream'}: unknown encoding."
    next
  end

  # Get merged file / text content metadata from a temp UTF-8 copy:
  source_encoding and source.set_encoding(source_encoding)
  source = source.dump!(external_encoding: Encoding::UTF_8)
  metadata.merge!(content_queue.compile(source))

  # Let MMD create a HTML output file:
  html = Tempfile.new([TMP, '.html'])
  html.close
  mmd.convert_file(source, output_file: html, full_document: true)

  # Create Evernote note from HTML output file (in default notebook, with fallback title):
  new_note  = 'newNote'
  fallback  = filename && filename.to_applescript || '(current date as text)'
  note_path = Metadata::Helpers::EvernoteRunner.new.run_script(
    %Q{set #{new_note} to (create note from file (#{html.to_applescript}) title #{fallback})},
    get_note_path_for: new_note
  )
  note = Metadata::Helpers::NotePath.new(note_path)

  # Set note title to H1 element content of HTML source (if any):
  title = String(REXML::Document.new(File.new(html.path)).root.text('body/h1')) rescue nil
  title_writer.write(note, title) unless title.nil? || title.empty?

  # Write recognized metadata to created note:
  metadata.each do |key, value|
    writer = writers.find(->{ [nil, nil] }) {|pattern, _| key =~ pattern }[1]
    writer and note = writer.write(note, value)
  end
end
