# encoding: UTF-8
require 'forwardable'
require 'pathname'
require 'semver'
require 'shellrun'

# Wrapper for the `multimarkdown` binary: get best version, get metadata, convert files.
class MultiMarkdownParser
  MINIMUM_VERSION  = '4.0.0'

  BASELINE_VERSION = '4.3.0'
  attr_reader :version

  extend Forwardable
  def_delegators :@bin, :to_path, :to_s, :expand_path, :realpath, :realdirpath, :dirname, :basename, :parent
  def_delegators :@bin, :size, :stat, :atime, :ctime, :owned?, :grpowned?, :symlink?, :readlink

  alias_method :bin, :to_path
  alias_method :to_str, :to_s

  def initialize
    @sh  = ShellRunner.new

    # get all `multimarkdown` binaries in PATH and env
    found = @sh.run_command('bash', '-lc', 'echo $MULTIMARKDOWN; which -a multimarkdown')
    found = found.split($/).reject {|l| l.empty? }
    fail 'No MultiMarkdown processor found: install MMD into your PATH, or export $MULTIMARKDOWN to point to it.' if found.empty?

    # filter down to executable binaries only
    executable = found.select {|bin| File.executable?(bin) }
    fail "No executable MultiMarkdown processor found among:#{list_join(*found)}" if executable.empty?

    # collect MultiMarkdown binaries >= MINIMUM_VERSION
    compatible = {}
    executable.each do |bin|
      versinfo = @sh.run_command(bin, '-v').match(/MultiMarkdown version ([^[:space:]]+)/i)
      if versinfo
        version         = SemanticVersion.new(versinfo[1])
        compatible[bin] = version if version >= MINIMUM_VERSION
      end
    end

    # get highest compatible MultiMarkdown version
    best_bin = compatible.max_by {|bin, version| version }
    best_bin or fail "No MultiMarkdown processor version #{MINIMUM_VERSION} or better found among:#{list.join(*found)}"
    @version = best_bin[1]
    @bin     = Pathname.new(best_bin[0])
  end

  def load_file_metadata(file, *fallback_keys)
    path     = File.expand_path(file)
    metadata = {}

    keys = if @version >= BASELINE_VERSION
        # gather available metadata keys from file if '-m' option is supported
        @sh.run_command(bin, '-m', path).split($/)
      elsif fallback_keys.count > 0
        # else use fallback keys (if any)
        fallback_keys.map!(&:to_s)
        warn "MultiMarkdown version #{@version} does not support the '-m' option."
        warn "Only the following metadata will be queried:#{list_join(*fallback_keys)}"
        fallback_keys
      end

    keys.each do |key| metadata[key] = @sh.run_command(bin, '-e', key, path) end
    metadata
  end

  def convert_file(markdown_file, to_format: :html, output_file: nil, full_document: false)
    opts = []
    opts.push('-t', String(to_format).downcase)    if to_format
    opts.push('-o', File.expand_path(output_file)) if output_file
    opts.push('-f')                                if full_document == true
    @sh.run_command(self.bin, *opts, File.expand_path(markdown_file))
  end

  private
  def list_join(*args)
    args.count == 1 ? " #{args[0]}" : "#{$/}* #{args.join("#{$/}* ")}"
  end
end
