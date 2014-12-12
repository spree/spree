module Spree
  class LocalizedNumber

    # Strips all non-price-like characters from the number, taking into account locale settings.
    def self.parse(number)
      return number unless number.is_a?(String)

      separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
      non_number_characters = /[^0-9\-#{separator}]/

      # strip everything else first
      number.gsub!(non_number_characters, '')
      # then replace the locale-specific decimal separator with the standard separator if necessary
      number.gsub!(separator, '.') unless separator == '.'

      number.to_d
    end

  end
end
