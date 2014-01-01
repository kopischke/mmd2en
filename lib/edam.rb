# encoding: UTF-8

# Quick and dirty module to group Evernote data format restraints.
# Source: http://dev.evernote.com/doc/reference/Limits.html.
module EDAM
  VERSION = '1.0.0'

  NOTEBOOK_NAME_LEN_MAX    = 100
  NOTE_RESOURCES_MAX       = 100
  NOTE_TITLE_LEN_MAX       = 255
  NOTE_TAGS_MAX            = 100
  TAG_NAME_LEN_MAX         = 100

  # Sieve to conform String input to Evernote restrictions.
  class StringSieve
    attr_reader :min_chars, :max_chars, :also_strip, :ellipsis

    def initialize(min_chars: 1, max_chars: nil, strip_chars: nil, ellipsis: '…')
      @min_chars  = min_chars
      @max_chars  = max_chars
      @also_strip = strip_chars
      @ellipsis   = ellipsis
    end

    def strain(string)
      max_chars = @max_chars || string.length
      string.strip!
      string.gsub!(/[\p{Cc}\p{Zl}\p{Zp}#{@also_strip}]/, '')
      string = string[0...max_chars-@ellipsis.length] << @ellipsis if string.length > max_chars
      string if string.length >= @min_chars
    end
  end

  # Sieve to conform Array input to Evernote restrictions.
  class ArraySieve
    attr_reader :min_items, :max_items, :item_sieve

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
