# encoding: UTF-8
require 'forwardable'
require 'pathname'

require_relative 'semver'
require_relative 'shellrun'

class MultiMarkdownParser
  attr_reader :version

  extend Forwardable
  def_delegators :@bin, :to_path, :to_s, :expand_path, :realpath, :realdirpath, :dirname, :basename, :parent
  def_delegators :@bin, :size, :stat, :atime, :ctime, :owned?, :grpowned?, :symlink?, :readlink

  def initialize
    @sh      = ShellRunner.new
    mmds     = @sh.run_command('which', '-a', 'multimarkdown').split($/)
    mmds     = [File.expand_path(ENV['MULTIMARKDOWN'])] | mmds unless String(ENV['MULTIMARKDOWN']).strip.empty?
    runnable = mmds.find {|mmd| File.executable?(mmd) }
    runnable or fail 'No MultiMarkdown processor found: install MMD into your PATH, or export $MULTIMARKDOWN to point to it.'
    @bin     = Pathname.new(runnable)
    versinfo = @sh.run_command(bin, '-v').match(/MultiMarkdown version ([^[:space:]]+)/i)
    versinfo and @version = SemanticVersion.new(versinfo[1])
  end

  alias_method :bin, :to_path
  alias_method :to_str, :to_s

  def load_file_metadata(file, *fallback_keys)
    metadata = {}
    keys = keys_listable? ? @sh.run_command(bin, '-m', file.path).split($/) : fallback_keys
    keys.each do |key| metadata[key] = @sh.run_command(bin, '-e', key, file.path) end
    metadata
  end

  def convert_file(markdown_file, to_format: :html, output_file: nil)
    opts = []
    to_format   and opts.push('-t', String(to_format).downcase)
    output_file and opts.push('-o', output_file.path)
    @sh.run_command(bin, *opts, markdown_file.path)
  end

  private
  def keys_listable?
    @version && @version >= '4.3'
  end
end
