# encoding: UTF-8
require 'CFPropertyList'

module OSX
  module PList
    def self.open(path)
      file        = get_plist(path)
      plist       = CFPropertyList::List.new(file: file)
      plist_data  = CFPropertyList.native_types(plist.value)

      return plist_data unless block_given?

      edited_data = yield plist_data
      unless edited_data == plist_data # do not write unmodified data
        plist.formatted = true
        plist.value     = CFPropertyList.guess(edited_data, convert_unknown_to_string: true)
        plist.save(file)
      end
    end

    private
    # Return a bundle‘s Info.plist if the bundle path is passed.
    def self.get_plist(path)
      info_plist = File.join(path, 'Contents', 'Info.plist')
      File.directory?(path) && File.exist?(info_plist) ? info_plist : path
    end
  end
end
