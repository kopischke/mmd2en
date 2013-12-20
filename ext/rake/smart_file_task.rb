# encoding: UTF-8
require 'rake/tasklib'
require 'rake/output'
require 'rake/task_info'

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
    def group;    @group_task.name unless @group_task.nil?; end
    def tasks;    @@tasks.fetch(@group_task.name, []); end
    def defined?; @defined; end

    @@groups ||= []
    @@tasks  ||= Hash.new([])

    # binds `puts` to Rake default output, quiet unless @verbose is set
    include Rake::ReducedOutput

    def initialize(target = nil, base = nil, action = nil, named_task_info: nil, group_task_info: nil, verbose: false)
      @target         = target
      @base           = Array(base)
      @action         = action
      self.named_task = named_task_info
      self.group_task = group_task_info
      @verbose        = verbose
      @defined        = false

      yield(self) if block_given?

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
    def parse_task_info(task_info)
      Rake::TaskInfo.parse(task_info) unless task_info.nil?
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
        desc @named_task.desc unless @named_task.desc.nil?
        task @named_task.name => @target
      end

      # :@group_task task (if provided)
      unless @group_task.nil?
        base_task = @named_task.nil? ? @target : @named_task.name
        desc @group_task.desc unless @group_task.desc.nil?
        task @group_task.name => base_task

        @@groups << @group_task.name
        @@tasks[@group_task.name] << base_task
      end

      @defined = true
    end
  end
end
