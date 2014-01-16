# encoding: UTF-8
module FileEncoding
  # Queryable byte distribution representation for a file.
  # @author Martin Kopischke
  # @version {FileEncoding::VERSION}
  class ByteSet
    # @return [File] the file object whose byte structure is exposed.
    attr_reader :file

    # @return [Integer] `file`’s total byte count.
    attr_reader :count

    # @return [Integer] the number of bytes queried from `file` when creating the ByteSet.
    attr_reader :chunk_size

    # Create a ByteSet from a file.
    # @param file [File, String] the file or pathname to a file queried.
    # @param chunk_size [Integer] the number of bytes to query from `file`.
    def initialize(file, chunk_size = nil)
      @count_of   = Hash.new(0)
      @count      = 0
      @file       = File.open(file) {|fd|
        while (byte = fd.getbyte) && (chunk_size.nil? || @count < chunk_size)
          @count_of[byte] += 1
          @count          += 1
        end
        fd
      }
      @chunk_size = Integer(chunk_size) unless chunk_size.nil?
    end

    # Return the first byte(s) of the file, in order.
    # @param count [Integer] number of bytes to return.
    # @return [Integer] if a single byte is specified in `count` (the default).
    # @return [Array] if more than one byte is specified in `count`.
    def first(count = 1)
      bytes = []
      File.open(@file) do |file|
        count.times { bytes << file.getbyte }
      end
      count == 1 ? bytes.first : bytes
    end

    # Check if the file starts with a certain byte sequence.
    # @param bytes [Array] the sequence of bytes to check, in order.
    # @return true if `bytes` matches the starting byte sequence.
    # @return false if `bytes` does not match the starting byte sequence.
    # @note any `bytes` argument is considered a match set, with multiple members being `OR` matched.
    def starts_with?(*bytes)
      File.open(@file) do |file|
        bytes.all? {|byte| Array(byte).include?(file.getbyte) }
      end
    end

    alias_method :start_with?, :starts_with?

    # The total count of queried bytes in the file.
    # @param bytes [Array] the bytes to count, in no particular order.
    # @return [Integer] the sum count of all `bytes` present in the file.
    # @note all arguments in `bytes` are mapped to a flat Array.
    def count_of(*bytes)
      bytes.flat_map {|e| Array(e) }.reduce(0) {|count, byte| count + @count_of[byte] }
    end

    # The ratio of queried bytes to the total byte count of the file.
    # @param bytes see #count_of.
    # @return [Float] the ratio of the sum count of all `bytes` to the file’s byte count.
    def ratio_of(*bytes)
      count_of(*bytes).to_f / @count
    end
  end
end
