# encoding: UTF-8
require 'CFPropertyList'

class InfoPList
  attr_accessor :data
  attr_reader   :file

  def initialize(bundle_path)
    @file  = File.join(bundle_path, 'Contents', 'Info.plist')
    @plist = CFPropertyList::List.new(file: @file)
    @data  = CFPropertyList.native_types(@plist.value)
  end

  def write!
    @plist.value = CFPropertyList.guess(@data, convert_unknown_to_string: true)
    @plist.save(@file, CFPropertyList::List::FORMAT_BINARY)
  end
end
