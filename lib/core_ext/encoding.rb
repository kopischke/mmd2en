# encoding: UTF-8
module CoreExtensions
  class ::Encoding
    # Find IANA mappings `Encoding.find` will miss.
    # http://www.iana.org/assignments/character-sets/character-sets.xhtml
    def self.find_iana_charset(name)
      iana_mappings = {
        'macintosh'    => 'macRoman',
        'unknown-8bit' => nil
      }
      ruby_encoding = iana_mappings.fetch(String(name).downcase, name)
      ruby_encoding and self.find(ruby_encoding)
    end
  end
end
