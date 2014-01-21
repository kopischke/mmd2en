# encoding: UTF-8
require 'delegate'
require 'pathname'
require 'semantic_version'
require 'shellrun'

# Wrapper for the `multimarkdown` binary: get best version, get metadata, convert files.
# @author Martin Kopischke
# @version 1.0.0
class MultiMarkdownParser < DelegateClass(Pathname)
  # Minimum `multimarkdown` version for metadata collection support.
  MINIMUM_VERSION  = '4.0.0'

  # Optimal `multimarkdown` version for best metadata collection support.
  BASELINE_VERSION = '4.3.0'

  # @return [SemanticVersion] the version of the used binary.
  attr_reader :version

  def initialize
    @sh = ShellRunner.new

    # get all unique `multimarkdown` binaries in PATH and env
    found = @sh.run_command('bash', '-lc', 'echo $MULTIMARKDOWN; which -a multimarkdown')
    found = found.split($/).reject {|l| l.empty? }.uniq
    fail 'No MultiMarkdown processor found: install MMD into your PATH, or export $MULTIMARKDOWN to point to it.' if found.empty?

    # filter down to executable binaries only
    executable = found.select {|bin| File.executable?(bin) }
    fail "No executable MultiMarkdown processor found among:#{list_join(*found)}" if executable.empty?

    # filter down to binaries with version >= MINIMUM_VERSION
    compatible = executable.each.with_object({}) {|bin, collect|
      versinfo = @sh.run_command(bin, '-v').match(/MultiMarkdown version ([^[:space:]]+)/i)
      if versinfo
        version      = SemanticVersion.new(versinfo[1])
        collect[bin] = version if version >= MINIMUM_VERSION
      end
    }

    # get binary with highest compatible version
    best_bin, best_version = compatible.max_by {|bin, version| version }
    best_bin or fail "No MultiMarkdown processor version #{MINIMUM_VERSION} or better found among:#{list.join(*found)}"
    @version = best_version
    @bin     = Pathname.new(best_bin)
    super(@bin)
  end

  # Load MultiMarkdown metadata from a file.
  # @param file [File, String] the file containing the metadata.
  # @param fallback_keys [Array<#to_s>] the metadata keys to query by name
  #   if the full list of keys contained in `file` cannot be retrieved.
  # @return [Hash] the collected metadata.
  def load_file_metadata(file, *fallback_keys)
    path = File.expand_path(file)

    keys = if @version >= BASELINE_VERSION
        # gather available metadata keys from file if '-m' option is supported
        @sh.run_command(@bin.to_path, '-m', path).split($/)
      elsif fallback_keys.count > 0
        # else use fallback keys (if any)
        fallback_keys.map!(&:to_s)
        warn "MultiMarkdown version #{@version} does not support the '-m' option."
        warn "Only the following metadata will be queried:#{list_join(*fallback_keys)}"
        fallback_keys
      end
    keys.each.with_object({}) do |key, data| data[key] = @sh.run_command(@bin.to_path, '-e', key, path) end
  end

  # Convert a MultiMarkdown file to a defined output format.
  # @param markdown_file [File, String] the file to convert.
  # @param to_format [Symbol] an output format support by `multimarkdown` (defaults to html).
  # @param output_file [File, String] the file to write the output to (STDOUT if nil).
  # @param full_document [Boolean] generate a full HTML document (defaults to true).
  def convert_file(markdown_file, to_format: :html, output_file: nil, full_document: false)
    opts = []
    opts.push('-t', String(to_format).downcase)    if to_format
    opts.push('-o', File.expand_path(output_file)) if output_file
    opts.push('-f')                                if full_document == true
    @sh.run_command(@bin.to_path, *opts, File.expand_path(markdown_file))
  end

  private
  # Create a nicely formatted plain text list from arguments.
  # @param args [Array<#to_s>] the list elements to join.
  # @return [String] the formatted plain text list of all *args`.
  def list_join(*args)
    args.count == 1 ? " #{args[0]}" : "#{$/}* #{args.join("#{$/}* ")}"
  end
end
