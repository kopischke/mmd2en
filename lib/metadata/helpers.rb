# encoding: UTF-8
require 'applescripter'

module Metadata
  module Helpers
    # AppleScript runner targeting Evernote by bundle ID
    # (targeting by name fails when the main app is not running, see http://discussion.evernote.com/topic/35147-applescript-open-by-id/#entry190353).
    # Returns a note path suitable as input for NotePath.new() if `descriptor` is given.
    class EvernoteRunner < AppleScripter::OSARunner
      def tell_command
        %Q{tell application id "com.evernote.evernote"}
      end

      def run_script(*lines, get_note_path_for: nil)
        if target = get_note_path_for
          lines << %Q{try}
          lines << %Q{get (name of notebook of #{target}) & "\n" & (local id of #{target})}
          lines << %Q{end try}
        end
        super(tell_command, *lines, %Q{end tell})
      end
    end

    # Access a note via its notebook and local id.
    class NotePath
      attr_reader :notebook, :id

      def initialize(path_string)
        note_path = path_string.split($/)
        @notebook = note_path[0]
        @id       = note_path[1]
      end
    end
  end
end
