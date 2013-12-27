# encoding: UTF-8
require 'rake/smart_file_task'
require 'mustache'

module Rake
  # Rake task to generate files from Mustache templates using a CLI-like approach
  # (but without actually using the broken mess the CLI is as of 0.99.5).
  class MustacheTask < SmartFileTask
    attr_accessor :data
    protected     :on_run # set by MustacheTask

    def initialize(target, template_file: nil, data: nil, &block)
      @target       = target
      @data         = data
      self.template = template_file
      self.on_run do
        puts "Rendering Mustache template '#{self.template.pathmap('%f')}' to '#{self.target.pathmap('%f')}'..."
        Mustache.template_file = self.template
        File.write(self.target, Mustache.render(self.data.respond_to?(:call) ? self.data.call(self) : self.data))
      end
      super(target, template, &block)
    end

    def template
      @template ||= @target and "#{@target}.mustache"
    end

    def template=(template_file)
      @deps and @deps.reject! {|e| e == self.template }
      @template = template_file
      @deps    |= [self.template]
    end
  end
end
