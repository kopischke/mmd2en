# encoding: UTF-8
require_relative 'test_helper'

Dir.glob(File.join(File.dirname(__FILE__), File.basename(__FILE__, '.rb'), '*.rb')).each do |f| load f end
