# encoding: UTF-8
require 'forwardable'
require 'pathname'
require 'semver'
require 'shellrun'

# Wrapper for the `multimarkdown` binary: get best version, get metadata, convert files.
class MultiMarkdownParser
  MINIMUM_VERSION  = '4.0.0'
  METADATA_VERSION = '4.3.0'

  attr_reader :version

  extend Forwardable
  def_delegators :@bin, :to_path, :to_s, :expand_path, :realpath, :realdirpath, :dirname, :basename, :parent
  def_delegators :@bin, :size, :stat, :atime, :ctime, :owned?, :grpowned?, :symlink?, :readlink

  def initialize
    @sh  = ShellRunner.new

    # get all `multimarkdown` binaries in PATH and env
    found = @sh.run_command('bash', '-lc', 'which -a multimarkdown').split($/)
    found = [ENV['MULTIMARKDOWN']] | found unless ENV['MULTIMARKDOWN'].nil?
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
    @version = compatible.values.compact.sort.last or
      fail "No MultiMarkdown processor version #{MINIMUM_VERSION} or better found among:#{list.join(*found)}"
    @bin     = Pathname.new(compatible.find {|k,v| v == @version }[0])
  end

  alias_method :bin, :to_path
  alias_method :to_str, :to_s

  def load_file_metadata(file, *fallback_keys)
    metadata = {}
    keys = if @version >= METADATA_VERSION
      @sh.run_command(bin, '-m', file.path).split($/)
    elsif fallback_keys.count > 0
      warn "MultiMarkdown version #{@version} does not support the '-m' option."
      warn "Only the following metadata will be queried:#{list_join(*fallback_keys)}"
      fallback_keys
    end
    keys.each do |key| metadata[key] = @sh.run_command(bin, '-e', key, file.path) end
    metadata
  end

  def convert_file(markdown_file, to_format: :html, output_file: nil, full_document: false)
    opts = []
    opts.push('-t', String(to_format).downcase) if to_format
    opts.push('-o', output_file.path)           if output_file
    opts.push('-f')                             if full_document == true
    @sh.run_command(bin, *opts, markdown_file.path)
  end

  private
  def list_join(*args)
    args.count == 1 ? " #{args[0]}" : "#{$/}* #{args.join("#{$/}* ")}"
  end
end
