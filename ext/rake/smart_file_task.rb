# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'

module Rake
  # Rake task class for smart file generation / processing tasks:
  # auto-target dir creation, optional named task alias, optional named group task.
  class SmartFileTask < TaskLib
    attr_accessor :target, :base, :action, :named_task, :group_task, :verbose
    class << self
      def tasks;  @@tasks;  end
      def groups; @@groups; end
    end
    def group;    @group_task.keys.first unless @group_task.nil?; end
    def tasks;    @@tasks[group]; end
    def defined?; @defined; end

    @@groups ||= Hash.new()
    @@tasks  ||= Hash.new([])

    # binds `puts` to Rake default output, quiet unless @verbose is set
    include Rake::ReducedOutput

    def initialize(target = nil, base = nil, action = nil, named_task: nil, group_task: nil, verbose: false)
      @target     = target
      @base       = base
      @action     = action
      @named_task = {task_name(named_task) => task_desc(named_task)} unless named_task.nil?
      @group_task = {task_name(group_task) => task_desc(group_task)} unless group_task.nil?
      @verbose    = verbose
      @defined    = false

      yield(self) if block_given?

      # join differing group descriptions the same way Rake does on multiple definitions
      @@groups[group] = [@@groups[group], @group_task.values.first].join(' / ') unless group.nil?

      # check we have neither empty nor nil requirements
      required = [@target, @base]
      define unless required.reject {|e| e.nil? || e.empty? }.count != required.count || @action.nil?
    end


  private
    def task_name(task_def)
      task_name = task_def.is_a?(Hash) ? task_def.keys.first : task_def
      String(task_name).strip.downcase.to_sym[/^.+$/]
    end

    def task_desc(task_def)
      String(task_def.values.first)[/^.+$/] if task_def.is_a?(Hash)
    end

    def define
      # directory task for @target folder creation
      target_dir = @target.pathmap('%d')
      directory target_dir

      # file task for @target creation
      file @target => [*@base, target_dir] do
        @action.call(self)
      end

      # :@named_task task (if provided)
      unless @named_task.nil?
        desc @named_task.values.first unless @named_task.values.first.nil?
        task @named_task.keys.first => @target
      end

      # :@group_task multitask (if provided)
      unless group.nil?
        @@tasks[group] << @named_task.nil? ? @target : @named_task.keys.first
        desc @group_task.values.first unless @group_task.values.first.nil?
        multitask @group_task.keys.first => tasks
      end

      @defined = true
    end
  end
end
