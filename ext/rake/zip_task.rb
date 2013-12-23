# encoding: UTF-8
require 'rake/smart_file_task'

module Rake
  # Rake task to generate ZIP archives wrapping the `zip` utility
  # (because `zip`, and hence PackageTask, are painful to configure).
  class ZipTask < SmartFileTask
    attr_accessor :files, :move, :recurse, :relative, :exclude
    protected     :on_run # set by ZipTask

    # syntactic sugar
    alias :archive  :target
    alias :archive= :target=

    def initialize(archive_file, *file_paths, &block)
      self.files = file_paths
      self.on_run do
        archive_path = self.target.sub(/(\.zip)?$/i, '.zip').shellescape
        self.files.sort.each do |path|
          zip_command = [].tap {|cmd|
            cmd << "cd #{File.dirname(path).shellescape};" if self.relative
            cmd << 'zip'
            cmd << '-v' if self.verbose
            cmd << '-m' if self.move
            cmd << '-r' if self.recurse
            cmd << archive_path
            cmd << (self.relative ? File.join('.', path.pathmap('%f')) : path).shellescape
            cmd << '-x' << self.exclude unless self.exclude.empty?
          }.flatten
          %x{#{zip_command.join(' ')}}
          fail "Error generating package archive '#{self.target}': `zip` returned #{$?.exitstatus}" unless $?.exitstatus == 0
        end
      end
      super(archive_file, files, &block)
    end
  end
end
