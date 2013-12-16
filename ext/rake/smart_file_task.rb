# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'

module Rake
  # Rake task class for smart file generation / processing tasks:
  # auto-target dir creation, optional named task alias, optional named group task.
  class SmartFileTask < TaskLib
    attr_accessor :target, :base, :action, :verbose
    attr_reader   :named_task, :group_task
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

    def initialize(target = nil, base = nil, action = nil, named_task_info: nil, group_task_info: nil, verbose: false)
      @target    = target
      @base      = base
      @action    = action
      named_task = named_task_info
      group_task = group_task_info
      @verbose   = verbose
      @defined   = false

      yield(self) if block_given?

      # join differing group descriptions the same way Rake does on multiple definitions
      @@groups[group] = [@@groups[group], @group_task.values.first].join(' / ') unless group.nil?

      # check we have neither empty nor nil requirements
      required = [@target, @base]
      define unless required.reject {|e| e.nil? || e.empty? }.count != required.count || @action.nil?
    end

    def named_task=(task_info)
      @named_task = parse_task_info(task_info)
    end

    def group_task=(task_info)
      @group_task = parse_task_info(task_info)
    end

  private
    def task_name(task_info)
      task_name = task_info.is_a?(Hash) ? task_info.keys.first : task_info
      String(task_name).strip.downcase.to_sym[/^.+$/]
    end

    def task_desc(task_info)
      String(task_info.values.first)[/^.+$/] if task_info.is_a?(Hash)
    end

    def parse_task_info(task_info)
      {task_name(task_info) => task_desc(task_info)} unless task_info.nil?
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
