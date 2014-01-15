# encoding: UTF-8
require 'core_ext/range'

module CoreExtensions
  # Extensions to the core Numeric class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::Numeric
    # Transpose `self` to a value in `to_range` proportional to `self`’s position in `from_range`.
    # @param from_range [Range<Numeric>] the numeric reference scale.
    # @param to_range [Range<Numeric>] the numeric target scale.
    # @return [Integer] if `self` and the transposed value of `self` are integral.
    # @return [Float] if either `self` or the transposed value of `self` is not integral.
    def scale(from_range, to_range)
      ranges = [from_range, to_range]
      ranges.each do |r| r.is_a?(Range) or fail ArgumentError, "Not a Range: '#{r}'." end

      from_step_size, to_step_size = ranges.map {|r| r.end - r.begin }
      base   = self - from_range.begin
      step   = base.to_f / from_step_size
      scaled = step * to_step_size + to_range.begin

      case
      when scaled < to_range.min then to_range.min  # only works with Range Core Extension
      when scaled > to_range.max then to_range.max  # – will barf in plain Ruby.
      when self.integer? && Integer(scaled) == scaled then Integer(scaled)
      else scaled
      end
    end
  end
end
