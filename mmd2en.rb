# encoding: UTF-8
require 'rexml/document'
require 'tempfile'

require_relative 'lib/applescripter'
require_relative 'lib/core_ext'
require_relative 'lib/edam'
require_relative 'lib/metadata'
require_relative 'lib/mmd'

sources = ARGF.to_files
sources.empty? and exit

# Set up MMD parser and Tempfile key
mmd = MultiMarkdownParser.new
TMP = 'mmd2en'

# Create the metadata source processor queue:
processors =  Metadata::ProcessorQueue.new
processors << Metadata::YAMLFrontmatterProcessor.new
processors << Metadata::LegacyFrontmatterProcessor.new
processors << ->(file) { mmd.load_file_metadata(file, 'title', 'notebook', 'tags', 'keywords', 'url') }

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

sources.map(&:dump!).each do |source|
  begin
    # Get merged metadata from parser queue:
    metadata = processors.compile(source)

    # Let MMD create a HTML output file:
    html = Tempfile.new([TMP, '.html'])
    html.close
    mmd.convert_file(source, output_file: html)

    # Create Evernote note from HTML output file (in default notebook, with current date as title):
    new_note  = 'newNote'
    note_path = Metadata::Helpers::EvernoteRunner.new.run_script(
      %Q{set #{new_note} to (create note from file (#{html.to_applescript}) title (current date as text))},
      get_note_path_for: new_note
    )
    note = Metadata::Helpers::NotePath.new(note_path)

    # Set note title to H1 element content of HTML source (if any):
    title = String(REXML::Document.new(File.new(html.path)).root.text('body/h1')) rescue nil
    title_writer.write(note, title) unless title.nil?

    # Write recognized metadata to created note:
    metadata.each do |key, value|
      writer = writers.find(->{ [nil, nil] }) {|pattern, writer| key =~ pattern }[1]
      writer and note = writer.write(note, value)
    end

  ensure
    html.close!
  end
end
