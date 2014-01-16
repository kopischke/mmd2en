# encoding: UTF-8
require 'core_ext'
require 'shellrun'

module Metadata
  # Abstract base class providing a ShellRunner instance.
  # Define a `call` method to do the processing in children.
  class Processor
    def initialize
      @sh = ShellRunner.new
    end
    def call(file)
      nil
    end
  end

  class AggregatingProcessor < Processor
    attr_reader :keys
    def initialize(**keys, &block)
      keys.empty? and fail ArgumentError, "No aggregation keys given for #{self.class.name}."
      block.nil?  and fail ArgumentError, "No collector block given for #{self.class.name}."
      @keys      = keys
      @collector = block
      super()
    end

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
    def initialize(**keys)
      super(**keys) do |file, spotlight_key|
        out = @sh.run_command('mdls', '-raw', '-name', spotlight_key, file.expanded_path)
        @sh.ok? or fail "Unable to collect '#{spotlight_key}' data: `mdls` exited with status #{@sh.exitstatus}."
        out = out.lines.map {|l| l.strip.gsub(/(^(\(null\)|\(|\)),?$|^"|",?$)/, '')[/^.+$/] }.compact
        out.count > 1 ? out : out.first
      end
    end
  end

  # File system properties processor: extract given keys.
  class FilePropertiesProcessor < AggregatingProcessor
    def initialize(**keys)
      super(**keys) do |file, method|
        File.send(method, file)
      end
    end
  end
end
