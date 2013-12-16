# encoding: UTF-8
require 'rake/smart_file_task'

module Rake
  # Rake task to generate ZIP archives wrapping the `zip` utility
  # (because `zip`, and hence PackageTask, are painful to configure).
  class ZipTask < SmartFileTask
    attr_accessor :move, :recurse, :relative, :exclude

    # syntactic sugar
    alias :archive  :target
    alias :archive= :target=
    alias :files    :base
    alias :files=   :base=

    # restrict `actions` access to r/o
    protected :action=

    def initialize(archive_file, file_paths = nil, move: false, recurse: true, relative: true, exclude: [], **kwargs, &block)
      @move     = move
      @recurse  = recurse
      @relative = relative
      @exclude  = exclude
      action = ->(*_){
        archive_path = "#{@target.shellescape.sub(/\.zip$/i, '')}.zip"
        @base.sort.each do |path|
          zip_command = [].tap {|cmd|
            cmd << "cd #{File.dirname(path).shellescape};" if @relative
            cmd << 'zip'
            cmd << '-v' if @verbose
            cmd << '-m' if @move
            cmd << '-r' if @recurse
            cmd << archive_path
            cmd << (@relative ? File.join('.', path.pathmap('%f')) : path).shellescape
            cmd << '-x' << @exclude unless @exclude.empty?
          }.flatten
          %x{#{zip_command.join(' ')}}
          fail "Error generating package archive '#{@target}': `zip` returned #{$?.exitstatus}" unless $?.exitstatus == 0
        end
      }
      super(archive_file, file_paths, action, **kwargs, &block)
    end
  end
end
