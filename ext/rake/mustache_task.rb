# encoding: UTF-8
require 'rake/smart_file_task'
require 'mustache'

module Rake
  # Rake task to generate files from Mustache templates using a CLI-like approach
  # (but without actually using the broken mess the CLI is as of 0.99.5).
  class MustacheTask < SmartFileTask
    attr_accessor :data
    attr_writer   :template

    # restrict `actions` access to r/o
    protected :action=

    def initialize(target, template_file: nil, data: nil, **kwargs, &block)
      @target   = target
      @template = template_file
      @data     = data
      action    = ->(*_){
        puts "Rendering Mustache template '#{template.pathmap('%f')}' to '#{@target.pathmap('%f')}'..."
        Mustache.template_file = template
        File.write(@target, Mustache.render(@data.respond_to?(:call) ? @data.call(self) : @data))
      }
      super(target, template, action, **kwargs, &block)
    end

    def template
      @template ||= "#{@target}.mustache"
    end
  end
end
