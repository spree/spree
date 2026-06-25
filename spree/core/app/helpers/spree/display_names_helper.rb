module Spree
  module DisplayNamesHelper
    # @param code [String, Symbol]
    # @return [String]
    def locale_display_label(code)
      return if code.blank?

      content_tag(
        :span,
        Spree::DisplayNames.locale_label(code),
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
      countries.map { |country| [Spree::DisplayNames.country_option_label(country), country.id] }
    end
  end
end
