# encoding: UTF-8
module CoreExtensions
  # Extensions to the core File class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::File
    # Write content to a file line by line.
    #
    # @!macro [new] file.incremental_write
    #   Opens a new handle to the file in 'wb' mode, writes the content
    #   Line by line, then closes the handle. `content` that does not respond to
    #   #each_line will be converted to a String.
    # @param file [File, String] the file to write to.
    # @param content [#each_line, #to_s] the content to write.
    # @return [Integer] the number of bytes written.
    # @return [nil] if no encoding could be guessed or `file` is not an existing file.
    def self.incremental_write(file, content)
      content = String(content) unless content.respond_to?(:each_line)
      File.open(file, 'wb') do |f|
        content.each_line.with_object(0) do |line, bytes| bytes += f.write(line) end
      end
    end

    # Write content to the file line by line.
    #
    # @!macro file.incremental_write
    # @param (see self.incremental_write)
    # @return (see self.incremental_write)
    def incremental_write(content)
      File.incremental_write(self, content)
    end
  end
end
