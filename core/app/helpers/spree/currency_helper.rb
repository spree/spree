module Spree
  module CurrencyHelper
    def currency_options(selected_value = nil)
      selected_value ||= Spree::Config[:currency]
      currencies = ::Money::Currency.table.map do |_code, details|
        iso = details[:iso_code]
        [iso, "#{details[:name]} (#{iso})"]
      end
      options_from_collection_for_select(currencies, :first, :last, selected_value)
    end

    def supported_currency_options
      return if current_store.nil?

      current_store.supported_currencies_list.map(&:iso_code)
    end

    def should_render_currency_dropdown?
      return false if current_store.nil?

      current_store.supported_currencies_list.size > 1
    end
  end
end
