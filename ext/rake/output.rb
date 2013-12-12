# encoding: UTF-8
module Rake
  module DefaultOutput
  private
    def puts(message)
      rake_output_message(message)
    end
  end

  module ReducedOutput
  private
    def puts(message)
      rake_output_message(message) if (@verbose rescue false) || $VERBOSE || $DEBUG
    end
  end
end
