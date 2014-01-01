# encoding: UTF-8
require 'forwardable'

module Metadata
  # Incremental, ordered metadata gathering queue.
  class ProcessorQueue
    extend Forwardable
    def_delegators :@processors, :[], :<<, :push, :pop, :count, :length, :empty?, :each, :each_index

    def initialize()
      @processors = []
    end

    # Call all processors in order on `file`, normalizing and merging their returned metadata.
    # Processors raising a StandardError are skipped with a warning message.
    def compile(file)
      @processors.reduce({}) { |hash, processor|
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
