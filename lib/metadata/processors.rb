# encoding: UTF-8
require 'core_ext'
require 'shellrun'

# Markdown metatada file processor library.
# @author Martin Kopischke
# @version {Metadata::VERSION}
module Metadata
  # @abstract Override the `call` method to do the processing in children.
  # Base class providing a {ShellRunner} instance.
  class Processor
    # Initialize `@sh` with a new {ShellRunner} instance.
    def initialize
      @sh = ShellRunner.new
    end

    # @param file [File, String] the file to process.
    # @return [nil]
    def call(file)
      nil
    end
  end

  # Metadata aggregated by a collector block.
  class AggregatingProcessor < Processor
    # @return [Hash] mapping of metadata key => item(s) to pass to collector.
    attr_reader :keys

    # @param keys [Hash] mapping of metadata key => item(s) to pass to the collector block.
    # @param block [Proc] the collector for metadata.
    # @raise [ArgumentError] if the `keys` mapping or `block` is missing.
    # @see SpotlightPropertiesProcessor
    # @see FilePropertiesProcessor
    def initialize(**keys, &block)
      keys.empty? and fail ArgumentError, "No aggregation keys given for #{self.class.name}."
      block.nil?  and fail ArgumentError, "No collector block given for #{self.class.name}."
      @keys      = keys
      @collector = block
      super()
    end

    # Call collector on `file` for each key it has to look for.
    # @param (see Processor#call)
    # @return [Hash] the collected metadata, indexed by `#keys.keys`.
    def call(file)
      {}.tap {|hash|
        @keys.each {|metatada_key, collector_items|
          metadata_for_key = Array(collector_items).map {|collector_item|
            instance_exec(file, collector_item, &@collector)
          }.flatten.compact.uniq

          unless metadata_for_key.empty?
            hash[metatada_key] = metadata_for_key.count == 1 ? metadata_for_key.first : metadata_for_key
          end
        }
      }
    end
  end

  # YAML front matter collected and stripped from the file.
  class YAMLFrontmatterProcessor < Processor
    def initialize
      require 'yaml'
      super
    end

    # Detect YAML frontmatter, collect its contents and strip it from `file`.
    # @param (see Processor#call)
    # @return [Array<(Hash, String)>] the collected metadata, indexed by the YAML frontmatter keys,
    #   and the content of `file`’ after stripping the YAML frontmatter.
    def call(file)
      metadata = {} if metadata == false || metadata.is_a?(String) # no actual frontmatter found
      path     = File.expand_path(file)
      unless metadata.empty?
        re = '^---[[:space:]]*$'
        content = @sh.run_command('sed', '-En', "1,/#{re}/{ /#{re}/!d; }; p", path, :|, 'sed', '-E', "/#{re}/,/#{re}/d")
      end
      [metadata, content]
    end
  end

  # Legacy pseudo MultiMarkdown metadata replaced by MMD conforming metadata keys.
  class LegacyFrontmatterProcessor < Processor
    # Replace legacy MultiMarkdown metadata in `file` by MMD conforming keys.
    # @param (see Processor#call)
    # @return [Array<(Hash, String)>] an empty metadata Hash and the transformed content of `file`.
    def call(file)
      path    = File.expand_path(file)
      content = @sh.run_command('sed', '-E', '1,/^[[:space:]]*$/{
        s/^@[[:space:]]+/Tags: /
        s/^=[[:space:]]+/Notebook: /
      }', path)
      @sh.ok? or fail "Unable to check '#{path}' for legacy front matter: `sed` exited with status #{@sh.exitstatus}."
      [{}, content]
    end
  end

  # Metadata keys mapped to designated Spotlight properties.
  class SpotlightPropertiesProcessor < AggregatingProcessor
    # @param keys [Hash] mapping of metadata key => Spotlight key(s) to pass to collector.
    def initialize(**keys)
      path  = File.expand_path(file)
      super(**keys) do |file, spotlight_key|
        @sh.ok? or fail "Unable to collect '#{spotlight_key}' data: `mdls` exited with status #{@sh.exitstatus}."
        out = @sh.run_command('mdls', '-raw', '-name', spotlight_key, file.path)
        out = out.lines.map {|l| l.strip.gsub(/(^(\(null\)|\(|\)),?$|^"|",?$)/, '')[/^.+$/] }.compact
        out.count > 1 ? out : out.first
      end
    end
  end

  # Metadata keys mapped to return values of `File` methods.
  class FilePropertiesProcessor < AggregatingProcessor
    # @param keys [Hash] mapping of metadata key => File method(s) to pass to collector.
    def initialize(**keys)
      super(**keys) do |file, method|
        File.send(method, file)
      end
    end
  end
end
