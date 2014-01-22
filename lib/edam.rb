# encoding: UTF-8

# Quick and dirty module to group Evernote data format restraints.
# @see http://dev.evernote.com/doc/reference/Limits.html Evernote Developer Documentation.
# @author Martin Kopischke
# @version {EDAM::VERSION}
module EDAM
  # The module version.
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

  # @abstract
  # @see EDAM::StringSieve
  # @see EDAM::ArraySieve
  class Sieve; end

  # Sanitizer and validator to conform String input to Evernote restrictions.
  class StringSieve < Sieve
    # @return [Integer] the minimum char length of the String.
    attr_reader :min_chars
    # @return [Integer] the maximum char length of the String.
    attr_reader :max_chars
    # @return [String] invalid characters other than those in {ALWAYS_STRIP}.
    attr_reader :also_strip
    # @return [String] the ellipsis character(s) to use when truncating the input.
    attr_reader :ellipsis

    # @param min_chars [Integer] the minimum char length of the String.
    # @param max_chars [Integer] the maximum char length of the String.
    # @param also_strip [String] invalid characters other than those in {ALWAYS_STRIP}.
    # @param ellipsis [String] the ellipsis character(s) to use when truncating the input.
    def initialize(min_chars: 1, max_chars: nil, also_strip: nil, ellipsis: '…')
      @min_chars  = min_chars
      @max_chars  = max_chars
      @also_strip = also_strip
      @ellipsis   = ellipsis
    end

    # Sanitize and validate String input.
    # @param string [String] the String input to strain.
    # @return [String, nil] the sanitized String, or nil if validation fails.
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
    # @return [Integer] the minimum number of items in the Array.
    attr_reader :min_items
    # @return [Integer] the maximum number of items in the Array.
    attr_reader :max_items
    # @return [EDAM::Sieve] the sieve to apply to the elements of the Array.
    attr_reader :item_sieve

    # @param min_items [Integer] the minimum number of items in the Array.
    # @param max_items [Integer] the maximum number of items in the Array.
    def initialize(min_items: 1, max_items: nil)
      @min_items  = min_items
      @max_items  = max_items
    end

    # @param sieve [EDAM::Sieve] the sieve to use on the list items.
    # @return [nil]
    # @raise [ArgumentError] if sieve is not a {EDAM::Sieve} object.
    def item_sieve=(sieve)
      fail ArgumentError, "Expected EDAM::Sieve, got #{sieve.class}!" unless sieve.is_a?(Sieve)
      @item_sieve = sieve
      @item_sieve.freeze
    end

    # Sanitize and validate Array input.
    # @param list [Array] the Array input to strain.
    # @return [Array, nil] the sanitized Array, or nil if validation fails.
    def strain(list)
      list = list.map {|item| @item_sieve.strain(item) }.compact if @item_sieve
      list.first(@max_items || list.count) if list.count >= @min_items
    end
  end
end
