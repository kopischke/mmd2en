# encoding: UTF-8
module CoreExtensions
  # Extensions to the core Range class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::Range
    # Fixes inverted Ranges returning nil on #min because Enumerable cannot iterate.
    # @return [Object] the endpoint first in ascending sort order.
    def min
      [self.begin, self.end].min
    end

    # Fixes inverted Ranges returning nil on #max because Enumerable cannot iterate.
    # @return [Object] the endpoint last in ascending sort order.
    def max
      [self.begin, self.end].max
    end
  end
end
