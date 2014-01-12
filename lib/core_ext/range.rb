# encoding: UTF-8
module CoreExtensions
  # Fix inverted Ranges returning `nil` on `#min` / `#max` because [Enumerable].
  class ::Range
    def min
      [self.begin, self.end].min
    end

    def max
      [self.begin, self.end].max
    end
  end
end
