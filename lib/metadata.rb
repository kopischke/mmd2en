# encoding: UTF-8
require_relative 'applescripter'
require_relative 'core_ext'
require_relative 'shellrun'

# Evernote metadata setting library.
module Metadata
  # Incremental, ordered metadata gathering queue.
  class ProcessorQueue
    extend Forwardable
    def_delegators :@processors, :[], :<<, :push, :pop, :count, :length, :empty?, :each, :each_index

    def initialize()
      @processors = []
    end

    # Call all processors in order on `file`, normalizing and merging their returned metadata.
    # Processors raising a StandardError are skipped with a warning message.
    def compile(file)
      @processors.reduce({}) { |hash, processor|
        begin
          metadata, content = processor.call(file)
          metadata = Hash[metadata.keys.map {|k| String(k).downcase }.zip(metadata.values)] # stringify keys
        rescue StandardError => e
          warn String(e)
          hash
        else
          unless content.nil?
            cursor = file.pos
            file.write(content)
            file.flush
            file.pos = cursor
          end
          hash.merge(metadata) # last value of identical keys wins
        end
      }
    end
  end

  # Abstract base class providing a ShellRunner instance.
  # Define a `call` method to do the processing in children.
  class Processor
    def initialize
      @sh = ShellRunner.new
    end
  end

  class AggregatingProcessor < Processor
    def initialize(**keys)
      keys or fail ArgumentError, "No aggregation keys given for #{self.class.name}."
      @keys = keys
      super()
    end

    def call(file)
      {}.tap {|hash|
        @keys.each {|target_key, property_keys|
          metadata_for_key = Array(property_keys).map {|key|
            @collector.call(file, key)
          }.flatten.compact.uniq

          unless metadata_for_key.empty?
            hash[target_key] = metadata_for_key.count == 1 ? metadata_for_key.first : metadata_for_key
          end
        }
      }
    end
  end

  # YAML front matter: detect, read and strip.
  class YAMLFrontmatterProcessor < Processor
    def initialize
      require 'yaml'
      super
    end

    def call(file)
      metadata = YAML.load_file(file.expanded_path) rescue false
      metadata = {} if metadata == false || metadata.is_a?(String) # no actual frontmatter found
      unless metadata.empty?
        re = '^---[[:space:]]*$'
        content = @sh.run_command('sed', '-En', "1,/#{re}/{ /#{re}/!d; }; p", file.expanded_path, :|, 'sed', '-E', "/#{re}/,/#{re}/d")
      end
      [metadata, content]
    end
  end

  # Legacy pseudo MultiMarkdown metadata: replace by MMD conforming metadata keys.
  class LegacyFrontmatterProcessor < Processor
    def call(file)
      content = @sh.run_command('sed', '-E', '1,/^[[:space:]]*$/{
        s/^@[[:space:]]+/Tags: /
        s/^=[[:space:]]+/Notebook: /
      }', file.expanded_path)
      @sh.ok? or fail "Unable to check '#{file.expanded_path}' for legacy front matter: `sed` exited with status #{@sh.exitstatus}."
      [{}, content]
    end
  end

  # Spotlight properties processor: extract given keys.
  class SpotlightPropertiesProcessor < AggregatingProcessor
    private
    def initialize(**keys)
      @collector = ->(file, spotlight_key) {
        out = @sh.run_command('mdls', '-raw', '-name', spotlight_key, file.expanded_path)
        @sh.ok? or fail "Unable to collect '#{spotlight_key}' data: `mdls` exited with status #{@sh.exitstatus}."
        out = out.lines.map {|l| l.strip.gsub(/(^(\(null\)|\(|\)),?$|^"|",?$)/, '')[/^.+$/] }.compact
        out.count > 1 ? out : out.first
      }
      super
    end
  end

  # File system properties processor: extract given keys.
  class FilePropertiesProcessor < AggregatingProcessor
    def initialize(**keys)
      @collector = ->(file, method){ File.send(method, file.expanded_path) }
      super
    end
  end

  # AppleScript based metadata setter.
  class Writer
    include AppleScripter
    attr_reader :key, :type, :item_type, :sieve

    def initialize(key, type: :text, item_type: :text, sieve: nil)
      @key       = key.strip
      @type      = type.downcase.to_sym
      @item_type = item_type.downcase.to_sym if type == :list
      @sieve     = sieve
      @runner    = Helpers::EvernoteRunner.new

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
        'notebook'    => ->(book)  { [acquire('theBook', 'notebook', book), %Q{move it to first item of theBook}].flatten },
        'tags'        => ->(tags)  { [acquire('theTags', 'tag', *tags), %Q{assign theTags to it}].flatten }
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
      return Metadata::Helpers::NotePath.new(output)
    end

    private
    def acquire(assignee, object, *names)
      [
        %Q{set #{assignee} to {}},
        %Q{repeat with theName in #{Array(names).to_applescript}},
        %Q{try},
        %Q{#{@runner.tell_command} to set end of #{assignee} to #{object} theName},
        %Q{on error},
        %Q{#{@runner.tell_command} to set end of #{assignee} to (make new #{object} with properties {name:theName})},
        %Q{end try},
        %Q{end repeat}
      ]
    end
  end

  module Helpers
    # AppleScript runner targeting Evernote by bundle ID
    # (targeting by name fails when the main app is not running, see http://discussion.evernote.com/topic/35147-applescript-open-by-id/#entry190353).
    # Returns a note path suitable as input for NotePath.new() if `descriptor` is given.
    class EvernoteRunner < AppleScripter::OSARunner
      def tell_command
        %Q{tell application id "com.evernote.evernote"}
      end

      def run_script(*lines, get_note_path_for: nil)
        if target = get_note_path_for
          lines << %Q{try}
          lines << %Q{get (name of notebook of #{target}) & "\n" & (local id of #{target})}
          lines << %Q{end try}
        end
        super(tell_command, *lines, %Q{end tell})
      end
    end

    # Access a note via its notebook and local id.
    class NotePath
      attr_reader :notebook, :id

      def initialize(path_string)
        note_path = path_string.split($/)
        @notebook = note_path[0]
        @id       = note_path[1]
      end
    end
  end
end
