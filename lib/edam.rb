# encoding: UTF-8

# Quick and dirty module to group Evernote data format restraints.
# Source: http://dev.evernote.com/doc/reference/Limits.html.
module EDAM
  VERSION = '1.0.0'

  # The maximum allowed char length of an Evernote notebook name.
  NOTEBOOK_NAME_LEN_MAX = 100
  # The maximum of resources that can be attached to an Evernote note.
  NOTE_RESOURCES_MAX    = 100
  # The maximum allowed char length of an Evernote note title.
  NOTE_TITLE_LEN_MAX    = 255
  # The maximum number of tags that can be attached to an Evernote note.
  NOTE_TAGS_MAX         = 100
  # The maximum allowed char length of an Evernote tag name.
  TAG_NAME_LEN_MAX      = 100
  # The character classes that are always removed from String data.
  ALWAYS_STRIP          = ['\p{Cc}', '\p{Zl}', '\p{Zp}']

  class Sieve; end

  # Sanitizer and validator to conform String input to Evernote restrictions.
  class StringSieve < Sieve
    attr_reader :min_chars
    attr_reader :max_chars
    attr_reader :also_strip
    attr_reader :ellipsis
    def initialize(min_chars: 1, max_chars: nil, also_strip: nil, ellipsis: '…')
      @min_chars  = min_chars
      @max_chars  = max_chars
      @also_strip = also_strip
      @ellipsis   = ellipsis
    end

    def strain(string)
      max_len = @max_chars || string.length
      string.strip!
      string.gsub!(/[#{ALWAYS_STRIP.join('')}#{@also_strip}]/, '')
      string = string[0...max_len-@ellipsis.length] << @ellipsis if string.length > max_len
      string if string.length >= @min_chars
    end
  end

  # Sanitizer and validator to conform Array input to Evernote restrictions.
  class ArraySieve < Sieve

    def initialize(min_items: 1, max_items: nil, item_sieve: nil)
      @min_items  = min_items
      @max_items  = max_items
      @item_sieve = item_sieve
    end

    def strain(list)
      list = list.map {|item| @item_sieve.strain(item) }.compact if @item_sieve
      list.first(@max_items || list.count) if list.count >= @min_items
    end
  end
end
