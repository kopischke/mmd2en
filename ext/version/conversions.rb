# encoding: UTF-8
class Version
  def to_friendly
    names = {'a' => 'alpha', 'b' => 'beta', 'rc' => 'release candidate'}
    match = String(self).match(/^(.+)(#{names.keys.join('|')})([[:digit:]]+)?$/i)
    match ? "#{match[1]} #{names[match[2]]} #{match[3]}" : self.to_s
  end
end
