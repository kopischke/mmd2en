# encoding: UTF-8
require 'applescripter'
require 'edam'
require 'metadata/helpers'
require 'pathname'
require 'time'

module Metadata
  # AppleScript based Evernote metadata setter.
  # @author Martin Kopischke
  # @version {Metadata::VERSION}
  class Writer
    include AppleScripter
    include EDAM
    include Metadata::Helpers

    # @return [String] the metadata key name.
    attr_reader :key
    # @return [Symbol] the data type of the metadata associated with {#key}.
    #   One of: :text, :date, :file, :list.
    attr_reader :type
    # @return [Symbol] the data type of the elements of a *:list* metadata key.
    #   One of: :text, :date, :file.
    attr_reader :item_type
    # @return [EDAM::Sieve] the EDAM sanitizer and validator to use.
    attr_reader :sieve

    # @param key [String] the metadata key name.
    # @param type [Symbol] the data type of the metadata associated with `key`.
    #   One of: :text, :date, :file, :list.
    # @param item_type [Symbol] the data type of the elements of a *:list* `key`.
    #   One of: :text, :date, :file.
    def initialize(key, type: :text, item_type: :text)
      @key       = key.downcase.strip
      @type      = type.downcase.to_sym
      @item_type = item_type.downcase.to_sym if type == :list
      @runner    = EvernoteRunner.new

      # lambdas used to normalize input data to expected type
      @normalizers = {
        list:  ->(input) { # split textual input on newlines and eventual StringSieve forbidden chars
          split = @sieve && @sieve.item_sieve.is_a?(StringSieve) ? /[#{@sieve.item_sieve.also_strip}\n]/ : $/
          list  = input.is_a?(String) ? input.split(split) : Array(input)
          list.map {|e| @normalizers[@item_type].call(e) }.compact.uniq
        },
        text:  ->(input) { String(input) },
        date:  ->(input) { DateTime.parse(String(input)) rescue nil },
        file:  ->(input) { Pathname.new(input) if File.readable?(input) rescue false },
        other: ->(input) { fail "unknown metadata type '#{type}'" }
      }

      # lambdas used to generate the AppleScript command to write metadata
      @writers = {
        'default'     => ->(value) { %Q{set #{@key} to #{value.to_applescript}} },
        'attachments' => ->(files) { files.map {|f| %Q{append attachment #{f.to_applescript}} } },
        'notebook'    => ->(book)  { acquire('theBook', 'notebook', book) << %Q{move it to first item of theBook} },
        'tags'        => ->(tags)  { acquire('theTags', 'tag', *tags)     << %Q{assign theTags to it} }
      }
    end

    # @param sieve [EDAM::Sieve] the sieve to use.
    # @return [nil]
    # @raise [ArgumentError] if sieve is not a {EDAM::Sieve} object.
    def sieve=(sieve)
      fail ArgumentError, "Expected EDAM::Sieve, got #{sieve.class}!" unless sieve.is_a?(Sieve)
      @sieve = sieve
      @sieve.freeze
    end

    # Write an Evernote note’s metadata.
    #
    # Will normalize `value` to the canonical format matching {#type}
    #   (with member data of `:list` types being normalized according to {#item_type}),
    #   apply the designated {#sieve} to the normalized input
    #   and write the resulting value, if not nil, to {#key} of `note`.
    #
    # @param note [Metadata::Helpers::NotePath] the note whose metadata is to be written.
    # @param value [Object] the value to set `note`’s {#key} to.
    # @return [Metadata::Helpers::NotePath] the created or updated note path.
    def write(note, value = nil)
      input = @normalizers.fetch(@type, @normalizers[:other]).call(value)
      input = @sieve.strain(input) if @sieve
      input.nil? and fail "value '#{value}' is empty after filtering."

      target = 'targetNote'
      script = [
        %Q{set #{target} to note id "#{note.id}" of notebook "#{note.notebook}"},
        %Q{tell #{target}},
        *@writers.fetch(@key, @writers['default']).call(input),
        %Q{end tell}
      ]
      out = @runner.run_script(*script, get_note_path_for: target)
      fail "`osascript` command exited with code: #{@runner.exitstatus}." unless @runner.ok?
      NotePath.new(out)
    end

    private
    # Ensure we have valid Evernote objects, creating them if necessary.
    # @param assignee [String] the Applescript list variable to return.
    # @param type [String] the type (AppleScript class) of Evernote object `names` designate.
    # @param names [Array<String>] the names of Evernote objects of type `object` to retrieve or create.
    # @return [Array<String>] the lines of an AppleScript command suitable for use with {#run_script}.
    def acquire(assignee, type, *names)
      [
        %Q{set #{assignee} to {}},
        %Q{repeat with theName in #{Array(names).to_applescript}},
        %Q{try},
        %Q{#{@runner.tell_command} to set end of #{assignee} to #{type} theName},
        %Q{on error},
        %Q{#{@runner.tell_command} to set end of #{assignee} to (make new #{type} with properties {name:theName})},
        %Q{end try},
        %Q{end repeat}
      ]
    end
  end
end
