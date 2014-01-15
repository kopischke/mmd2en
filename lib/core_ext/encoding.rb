# encoding: UTF-8
module CoreExtensions
  # Extensions to the core Encoding class.
  # @author Martin Kopischke
  # @version {CoreExtensions::VERSION}
  class ::Encoding
    # Find IANA mappings `Encoding.find` will miss.
    # @param name [String] the IANA charset name to match.
    # @return [Encoding] if a Ruby encoding matches `name`.
    # @return [nil] if no match is found.
    # @see  http://www.iana.org/assignments/character-sets/character-sets.xhtml IANA Character Set Reference
    def self.find_iana_charset(name)
      iana_mappings = {
        'macintosh'    => 'macRoman',
        'unknown-8bit' => nil         # yes, this is actually a IANA code (MIBEnum 2079)
      }
      ruby_encoding = iana_mappings.fetch(String(name).downcase, name)
      ruby_encoding and self.find(ruby_encoding)
    end
  end
end
