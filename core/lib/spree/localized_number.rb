module Spree
  class LocalizedNumber

    class << self
      # Strips all non-price-like characters from the number, taking into account locale settings.
      def parse!(number, default = nil)
        return number unless number.is_a?(String)

        separator, delimiter = I18n.t([:'number.currency.format.separator', :'number.currency.format.delimiter'])
        non_number_characters = /[^0-9\-#{separator}#{delimiter}]/

        # work on a copy, prevent original argument modification
        number = number.dup
        # strip everything else first, including thousands delimiter
        number.gsub!(non_number_characters, '')
        # then replace the locale-specific decimal separator with the standard separator if necessary
        number.gsub!(separator, '.') unless separator == '.'

        number.to_d
      rescue ArgumentError
        return default
      end

      def parse(string)
        parse!(string, 0)
      end
    end

  end
end
