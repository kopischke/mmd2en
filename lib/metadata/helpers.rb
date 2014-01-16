# encoding: UTF-8
require 'applescripter'

module Metadata
  # Evernote metadata processing helpers.
  # @author Martin Kopischke
  # @version {Metadata::VERSION}
  module Helpers
    # AppleScript runner targeting Evernote.
    class EvernoteRunner < AppleScripter::OSARunner
      # Get the AppleScript `tell` command needed to target Evernote by bundle ID
      # (as targeting by name fails when the main app is not running).
      # @see http://discussion.evernote.com/topic/35147-applescript-open-by-id/#entry190353
      # @return [String] the AppleScript `tell` command (without the `end tell` final).
      def tell_command
        %Q{tell application id "com.evernote.evernote"}
      end

      # Tell Evernote to execute an AppleScript.
      # @param  lines [Array<String>] the lines of the script to be executed.
      # @param  get_note_path_for [String] the descriptor of a note object whose path is needed (optional).
      # @return [String] the output of the AppleScript call. If `get_note_path_for` is true,
      #         this is a note path suitable as input for {NotePath#initialize}.
      def run_script(*lines, get_note_path_for: nil)
        if target = get_note_path_for
          lines << %Q{try}
          lines << %Q{get (name of notebook of #{target}) & "\n" & (local id of #{target})}
          lines << %Q{end try}
        end
        super(tell_command, *lines, %Q{end tell})
      end
    end

    # Notebook and local ID of an Evernote note.
    # Allows for direct addressing of note objects.
    class NotePath
      # @return [String] the name of the Evernote notebook object containing the note.
      attr_reader :notebook

      # @return [String] the local ID of the Evernote note object.
      attr_reader :id

      # Parse a “Notebook\nID” String into a NotePath.
      # @param path [#to_s] any object whose String is split over two lines.
      # @note  No validation of `path` contents happens.
      def initialize(path)
        @notebook, @id = String(path).split($/)
      end

      # Get the note path in the String format parsed by #new.
      # @return [String] “Notebook\nID”.
      def to_s
        [@notebook, @id].join($/)
      end

      alias_method :to_str, :to_s
    end
  end
end
