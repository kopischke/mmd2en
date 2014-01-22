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

    # Truncate a String to a maximum length, adding  an ellipsis if truncation occurs.
    # The ellipsis length is counted towards maximum length.
    # @param length [Integer] the length to truncate the string to.
    # @param ellipsis [String] the ellipsis to append if truncation occurs.
    # @return [String] a new, truncated String.
    # @raise [ArgumentError] if `length` is below the ellipsis length.
    def truncate(length, ellipsis = '…')
      "#{self}".truncate!(length, ellipsis)
    end

    # {include:String#truncate}
    # @param (see String#truncate)
    # @return [self] the String in truncated form.
    # @raise (see String#truncate)
    def truncate!(length, ellipsis = '…')
      ellipsis = String(ellipsis)
      raise ArgumentError, "Length value greater than #{ellipsis.length} needed, got #{length}!" unless length > ellipsis.length
      if length < self.length
        self[length - ellipsis.length..-1] = ''
        self << ellipsis
      end
      self
    end
  end
end
