# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'
require 'mustache'

module Rake
  # Rake task to generate files from Mustache templates using
  # programmatical data (as opposed to YAML files via CLI)
  class MustacheTask < TaskLib
    # name + path of generated file
    attr_accessor :target
    # name + path of Mustache template
    attr_accessor :template
    # data Hash to pass to template
    attr_accessor :data
    # verbose operation (defaults to false)
    attr_accessor :verbose

    # for conditional puts usage to Rake default output
    include Rake::VerboseOutput

    def initialize(target = nil)
      @target   = target
      @template = nil
      @data     = {}
      @verbose  = false
      yield self if block_given?
      define unless @target.nil?
    end

    def define
      file @target => template_file do
        unless File.directory?(target_dir)
          puts "Creating target directory '#{target_dir}'..."
          FileUtils.mkpaths target_dir
        end

        puts "Rendering Mustache template '#{template_file}' to '#{@target}'..."
        Mustache.template_file = template_file
        File.write @target, Mustache.render(@data)
      end

      desc "Run all Mustache generation tasks"
      task :mustache => @target
    end

  private
    def template_file
      @template or "#{@target.pathmap('%X')}.mustache"
    end

    def target_dir
      @target.pathmap('%d')
    end
  end
end
