# encoding: UTF-8
module Rake
  class TaskInfo
    attr_reader :name, :desc

    def initialize(task_name, task_desc = nil)
      self.name = task_name
      self.desc = task_desc
    end

    def name=(task_name)
      task_name = String(task_name).strip.downcase[/^.+$/]
      @name = task_name.to_sym unless task_name.nil?
    end

    def desc=(task_desc)
      @desc = String(task_desc).strip[/^.+$/]
    end

    # smartly return a TaskInfo from input
    def self.parse(*task_info)
      unless task_info.empty?
        if task_info.count == 1
          task_info = task_info.first
          return task_info.dup if task_info.is_a?(TaskInfo)
          task_info = Array(task_info).first if task_info.is_a?(Hash)
        end
        TaskInfo.new(*task_info)
      end
    end
  end
end
