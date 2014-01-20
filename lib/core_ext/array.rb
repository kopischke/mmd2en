# encoding: UTF-8
module CoreExtensions
  # Extensions to the core Array class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::Array
    # More than flattening.
    # @return [Array] if the array has more than one element: the flattened Array.
    # @return [Object] if the array has only one element: its first element.
    def squash
      self.count > 1 ? self.flatten : self.first
    end
  end
end
