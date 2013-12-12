# encoding: UTF-8
require 'rake/smart_file_task'
require 'mustache'

module Rake
  # Rake task to generate files from Mustache templates using
  # dynamically generated data (as opposed to static YAML data).
  class MustacheTask < SmartFileTask
    attr_accessor :data

    # syntactic sugar
    alias :template  :base
    alias :template= :base=

    # restrict `actions` and `args` access to r/o
    protected :action=, :args=

    def initialize(target, template_file: nil, data: nil, **kwargs, &block)
      @data  = data
      action = ->(*_){
        puts "Rendering Mustache template '#{@base.pathmap('%f')}' to '#{@target.pathmap('%f')}'..."
        Mustache.template_file = @base
        File.write(@target, Mustache.render(@data))
      }
      template_file = template_file || "#{target}.mustache"
      super(target, template_file, action, **kwargs, &block)
    end
  end
end
