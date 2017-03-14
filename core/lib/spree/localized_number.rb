module Spree
  class LocalizedNumber

    class << self

      # Strips all non-price-like characters from the number, taking into account locale settings.
      def parse!(number)
        return number unless number.is_a?(String)

        separator = I18n.t(:'number.currency.format.separator')
        non_number_characters = /[^0-9\-#{separator}]/

        # work on a copy, prevent original argument modification
        number = number.dup
        # strip everything else first, including thousands delimiter
        number.gsub!(non_number_characters, '')
        # then replace the locale-specific decimal separator with the standard separator if necessary
        number.gsub!(separator, '.') unless separator == '.'

        number.to_d
      end

      def parse(number)
        parse!(number)
      rescue ArgumentError
        return 0.0.to_d
      end

    end

  end
end
