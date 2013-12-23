# encoding: UTF-8
class Version
  @@prerelease_codes = {
    'a' => ['a', 'alpha'],
    'b' => ['b', 'beta'],
    'r' => ['rc', 'release candidate'],
    'g' => ['gm', 'golden master']
  }

  def to_short
    match = String(self).match(/^(.+)(#{@@prerelease_codes.keys.join('|')})([[:digit:]]*)$/i)
    match ? "#{match[1]}#{@@prerelease_codes[match[2]][0]}#{match[3]}" : self.to_s
  end

  def to_friendly
    names = {'a' => 'alpha', 'b' => 'beta', 'r' => 'release candidate', 'g' => 'golden master'}
    match = String(self).match(/^(.+)(#{@@prerelease_codes.keys.join('|')})([[:digit:]]*)$/i)
    match ? "#{match[1]} #{@@prerelease_codes[match[2]][1]} #{match[3]}".strip : self.to_s
  end
end
