# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'
require 'rake/task_info'

module Rake
  # Rake task class for smart file generation / processing tasks:
  # auto-target dir creation, optional named task alias, optional named group task.
  class SmartFileTask < TaskLib
    attr_accessor :target, :verbose
    attr_reader   :deps, :named_task, :group_task

    def group;    @group_task.name unless @group_task.nil?; end
    def tasks;    @@tasks.fetch(@group_task.name, []); end
    def defined?; @defined; end

    class << self
      def tasks;  @@tasks;  end
      def groups; @@groups; end
    end

    @@groups ||= []
    @@tasks  ||= Hash.new([])

    # binds `puts` to Rake default output, quiet unless @verbose is set
    include Rake::ReducedOutput

    def initialize(target, *dependencies)
      @target   = target
      @deps     = dependencies
      @defined  = false
      yield(self) if block_given?
      required = [@target, @deps]
      define unless required.reject {|e| e.nil? || e.empty? }.count != required.count || @action.nil?
    end

    def deps=(dependencies)
      @deps = Array(dependencies)
    end

    def on_run(*args, &block)
      @action = [block, args]
    end

    def named_task=(task_info)
      @named_task = parse_task_info(task_info)
    end

    def group_task=(task_info)
      @group_task = parse_task_info(task_info)
    end

  private
    def parse_task_info(task_info)
      Rake::TaskInfo.parse(task_info) unless task_info.nil?
    end

    def define
      # directory task for @target folder creation
      target_dir = @target.pathmap('%d')
      directory target_dir

      # file task for @target creation
      file @target => [*@deps, target_dir] do
        self.instance_exec(@action[1], &@action[0])
      end

      # :@named_task task (if provided)
      unless @named_task.nil?
        desc @named_task.desc unless @named_task.desc.nil?
        task @named_task.name => @target
      end

      # :@group_task task (if provided)
      unless @group_task.nil?
        base_task = @named_task.nil? ? @target : @named_task.name
        desc @group_task.desc unless @group_task.desc.nil?
        task @group_task.name => base_task

        @@groups << @group_task.name unless @@groups.include?(@group_task.name)
        @@tasks[@group_task.name] = tasks << base_task
      end

      @defined = true
    end
  end
end
