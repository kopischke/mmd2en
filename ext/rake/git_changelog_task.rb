# encoding: UTF-8
require 'date'
require 'rake/smart_file_task'
require 'shellwords'
require 'version'
require 'version/conversions'
require 'yaml'

module Rake
  class GitChangelogTask < SmartFileTask
    # Syntactic sugar
    alias_method  :logfile,  :target
    alias_method  :logfile=, :target=

    attr_accessor :format, :attribute, :filter, :with_tags
    protected     :on_run # set by GitChangelogTask

    Struct.new('GitCommit', :hash, :author, :blame, :date)

    def initialize(file, *dependencies, &block)
      @format       = '%s'
      @attribute    = :collaborators
      @filter       = nil
      @with_tags    = false

      self.on_run do
        puts 'Retrieving logged changes...'
        logged   = File.file?(self.target) ? YAML.load_file(self.target) : {}

        puts 'Compiling current release list...'
        releases = @with_tags ? %x{git tag}.chomp.split($/) : Version.current
        releases.reject! {|r| logged.keys.include?(r) }

        unless releases.empty?
          changes = {}
          releases.sort_by! {|r| DateTime.parse(%x{git log -1 --format=%ai #{r.shellescape}}.chomp) }

          releases.each.with_index do |r, i|
            puts "Gathering git commit data for release: #{r}"
            if @with_tags == true
              start = i > 0 ? releases[i-1] : logged.keys.first
              range = "#{start.shellescape << '..' unless start.nil?}#{r.shellescape}"
            else
              start = logged.keys.first and logged.keys.first['commit']
              range = "#{start << '..' unless start.nil?}HEAD"
            end
            r_data  = %x{git log -1 --format='%H%n%aN%n%aE%n%ai' #{range}}.chomp.split($/)

            unless r_data.empty?
              r_commit   = Struct::GitCommit.new(*r_data)
              messages   = %x{git log --format=#{msg_format.shellescape} #{range}}.chomp
              messages   = messages.split($/).reject {|msg| msg.match(@filter) }.join($/) if @filter == true
              messages.gsub!(/ \[#{r_commit.author}\]$/mi, '') if @attribute == :collaborators
              version    = ::Version.new(*r.split('.'))
              changes[r] = {
                'version'    => version.to_short,
                'title'      => version.to_friendly,
                'body'       => messages,
                'prerelease' => version.prerelease?,
                'author'     => r_commit.author,
                'blame'      => r_commit.blame,
                'date'       => r_commit.date,
                'commit'     => r_commit.hash
              }
            end
          end

          puts 'Re-writing change log...'
          ordered = changes.merge(logged).sort_by {|k,v| DateTime.parse(v['date']) }.reverse
          File.write(self.target, Hash[ordered].to_yaml)
        end
        puts "Releases processed: #{releases.count}."
      end

      super(file, *git_deps(file)) do |t|
        t.named_task = {changelog: "#{File.exist?(t.target) ? 'Update the' : 'Create a'} change log master file"}
        block.call(t) unless block.nil?
        t.deps |= git_deps(t.target)
      end
    end

    private
    def msg_format
      @format << (' [%cN]' unless @attribute.nil? || @attribute == :none).to_s
    end

    def git_deps(target)
      dir = File.dirname(target) unless File.directory?(target)
      dir = File.dirname(dir)     until File.directory?(File.join(dir, '.git')) || dir == '/'
      git = File.join(dir, '.git')
      FileList.new(@with_tags ? File.join(git, 'refs', 'tags', '*') : File.join(git, 'HEAD')) if File.directory?(git)
    end
  end
end
