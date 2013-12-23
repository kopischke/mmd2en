# encoding: UTF-8
require 'CFPropertyList'

module OSX
  module PList
    def self.open(path)
      plist       = CFPropertyList::List.new(file: path)
      plist_data  = CFPropertyList.native_types(plist.value)

      return plist_data unless block_given?

      edited_data = yield plist_data
      unless edited_data == plist_data # do not write unmodified data
        plist.formatted = true
        plist.value     = CFPropertyList.guess(edited_data, convert_unknown_to_string: true)
        plist.save(path)
      end
    end
  end
end
