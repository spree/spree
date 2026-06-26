module Spree
  module LocalizedNamesHelper
    # @param code [String, Symbol]
    # @return [String]
    def locale_display_label(code)
      return if code.blank?

      content_tag(
        :span,
        Spree::Locale.new(code: code).label,
        data: {
          controller: 'display-name',
          display_name_type_value: 'language',
          display_name_code_value: code
        }
      )
    end

    # @param countries [Enumerable<Spree::Country>]
    # @return [Array<Array>]
    def country_select_options(countries)
      countries.map { |country| [country.option_label, country.id] }
    end
  end
end
