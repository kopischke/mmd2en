# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'
require 'mustache'

module Rake
  # Rake task to generate files from Mustache templates using
  # dynamically generated data (as opposed to static YAML data).
  class MustacheTask < TaskLib
    attr_accessor :target, :named, :template, :data, :verbose
    @@targets ||= []

    # for conditional puts usage to Rake default output
    include Rake::VerboseOutput

    def initialize(target = nil)
      @target   = target    # path to file task target (mandatory)
      @named    = nil       # named task description (optional, Hash, skipped if missing)
      @template = nil       # path to Mustache template (optional, generated if missing)
      @data     = {}        # data to feed into Mustache template (optional, Hash)
      @verbose  = false
      yield self if block_given?
      unless @target.nil?
        @@targets.push(@target)
        define
      end
    end

  private
    def define
      # file task for @target creation
      file @target => template_file do
        unless File.directory?(target_dir)
          puts "Creating target directory '#{target_dir}'..."
          FileUtils.mkpaths(target_dir)
        end
        puts "Rendering Mustache template '#{template_file}' to '#{@target}'..."
        Mustache.template_file = template_file
        File.write(@target, Mustache.render(@data))
      end

      # named task @named (if provided)
      unless @named.nil? || named.empty?
        desc @named.values.first
        task @named.keys.first => @target
      end

      # catch-all Mustache task
      desc "Run all Mustache generation tasks"
      task :mustache => @@targets
    end

    def template_file
      @template or "#{@target.pathmap('%X')}.mustache"
    end

    def target_dir
      @target.pathmap('%d')
    end
  end
end
