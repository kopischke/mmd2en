# encoding: UTF-8
require 'applescripter'
require 'edam'
require 'metadata/helpers'
require 'pathname'
require 'time'

module Metadata
  # AppleScript based metadata setter.
  class Writer
    include AppleScripter
    attr_reader :key, :type, :item_type, :sieve
    include Metadata::Helpers

    def initialize(key, type: :text, item_type: :text, sieve: nil)
      @key       = key.downcase.strip
      @type      = type.downcase.to_sym
      @item_type = item_type.downcase.to_sym if type == :list
      @sieve     = sieve
      @runner    = EvernoteRunner.new

      # normalize input data to expected type
      @normalizers = {
        list:  ->(input) { # split textual input on newlines and eventual StringSieve forbidden chars
          split = @sieve && @sieve.item_sieve.is_a?(EDAM::StringSieve) ? /[#{@sieve.item_sieve.also_strip}\n]/ : $/
          list  = input.is_a?(String) ? input.split(split) : Array(input)
          list.map {|e| @normalizers[@item_type].call(e) }.compact.uniq
        },
        text:  ->(input) { String(input) },
        date:  ->(input) { DateTime.parse(String(input)) rescue nil },
        file:  ->(input) { Pathname.new(input) if File.readable?(input) rescue false },
        other: ->(input) { fail "unknown metadata type '#{type}'" }
      }

      # generate AppleScript command to write metadata
      @writers = {
        'default'     => ->(value) { %Q{set #{@key} to #{value.to_applescript}} },
        'attachments' => ->(files) { files.map {|f| %Q{append attachment #{f.to_applescript}} } },
        'notebook'    => ->(book)  { acquire('theBook', 'notebook', book) << %Q{move it to first item of theBook} },
        'tags'        => ->(tags)  { acquire('theTags', 'tag', *tags)     << %Q{assign theTags to it} }
      }
    end

    # Will normalize `value` to canonical formats depending on `@type`
    # (with member data of `:list` types being normalized according to `@item_type`),
    # apply the EDAM::Sieve type given in `@sieve` to the result
    # and write the resulting value, if not nil, to `@key` of `note`.
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
      output = @runner.run_script(*script, get_note_path_for: target)
      @runner.ok? or fail "`osascript` command exited with code: #{@runner.exitstatus}."

    rescue RuntimeError => e
      warn "Unable to set #{@key} for note ID '#{note.id}' of notebook '#{note.notebook}' to '#{value}': " << String(e)
      return note # fallback input for next writer in chain

    else
      return NotePath.new(output)
    end

    private
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
