module Spree
  class LocalizedNumber
    # Strips all non-price-like characters from the number, taking into account locale settings.
    def self.parse(number)
      return number unless number.is_a?(String)

      separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
      non_number_characters = /[^0-9\-#{separator}]/

      # work on a copy, prevent original argument modification
      number = number.dup
      # strip everything else first, including thousands delimiter
      number.gsub!(non_number_characters, '')
      # then replace the locale-specific decimal separator with the standard separator if necessary
      number.gsub!(separator, '.') unless separator == '.'

      # Returns 0 to avoid ArgumentError: invalid value for BigDecimal(): "" for empty string
      return 0 unless number.present?

      number.to_d
    end
  end
end
