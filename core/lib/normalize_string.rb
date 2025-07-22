require 'any_ascii'

module NormalizeString
  def self.normalize(string)
    return unless string.present?

    AnyAscii.transliterate(string)
  end

  def self.remove_emoji_and_normalize(string, keep_emoji_when_empty: false)
    return unless string.present?

    result = AnyAscii.transliterate(string.gsub(/\p{So}/, ''))
    return result if result.present? || !keep_emoji_when_empty

    normalize(string)
  end
end
