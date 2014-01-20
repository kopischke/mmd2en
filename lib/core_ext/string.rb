# encoding: UTF-8
module CoreExtensions
  # Extensions to the core String class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::String
    # Make sure the String ends with a punctuation mark, without duplicating the mark.
    # @param mark [String] the punctuation mark.
    # @return [String] a new String with the punctuation mark appended if it was missing.
    def punct(mark = '.')
      "#{self.chomp(mark)}#{mark}"
    end

    # {include:String#punct}
    # @param (see String#punct)
    # @return [String] the String with the punctuation mark appended if it was missing.
    def punct!(mark = '.')
      self.sub!(/#{Regexp.escape(mark)}?$/, mark)
    end
  end
end
