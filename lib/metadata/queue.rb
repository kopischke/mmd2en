# encoding: UTF-8
require 'forwardable'

# Markdown metatada file processor library.
# @author Martin Kopischke
# @version {Metadata::VERSION}
module Metadata
  # Incremental, ordered metadata gathering queue.
  class ProcessorQueue
    extend Forwardable
    # @!macro [attach] delegate
    #   @!method ${2}
    #     Equivalent to `Array#$2` for the Array of processors.
    def_delegator :@processors, :[]
    def_delegator :@processors, :<<
    def_delegator :@processors, :push
    def_delegator :@processors, :pop
    def_delegator :@processors, :count
    def_delegator :@processors, :length
    def_delegator :@processors, :empty?
    def_delegator :@processors, :each
    def_delegator :@processors, :each_index

    def initialize
      @processors = []
    end

    # Call all processors in order on `file`, normalizing and merging their returned metadata.
    # Processors raising a StandardError are skipped with a warning message.
    # @param file [File, String] the file to process.
    # @return [Hash] the metadata collected by all processors in the queue.
    # @note processors can request a modification of the contents of `file` by returning an Array
    #   of [Metadata, File content]. Do not pass files that should not be modified to the queue!
    def compile!(file)
      @processors.reduce({}) {|hash, processor|
        begin
          metadata, content = processor.call(file)
          metadata = Hash[metadata.keys.map {|k| String(k).downcase }.zip(metadata.values)] # stringify keys
        rescue StandardError => e
          warn String(e)
          hash
        else
          unless content.nil?
            cursor = file.pos
            file.write(content)
            file.flush
            file.pos = cursor
          end
          hash.merge(metadata) # last value of identical keys wins
        end
      }
    end
  end
end
