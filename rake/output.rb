# encoding: UTF-8
module Rake
  module StandardOutput
  private
    def puts(message)
      rake_output_message message
    end
  end

  module VerboseOutput
  private
    def puts(message)
      if @verbose || $VERBOSE || $DEBUG
        rake_output_message message
      end
    end
  end
end
