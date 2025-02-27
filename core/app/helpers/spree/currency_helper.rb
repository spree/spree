module Spree
  module CurrencyHelper
    def currency_options(selected_value = nil)
      selected_value ||= Spree::Store.default.default_currency
      currencies = ::Money::Currency.table.map do |_code, details|
        iso = details[:iso_code]
        [iso, "#{details[:name]} (#{iso})"]
      end
      options_from_collection_for_select(currencies, :first, :last, selected_value)
    end

    def supported_currency_options
      return if current_store.nil?

      current_store.supported_currencies_list.map(&:iso_code).map { |currency| currency_presentation(currency) }
    end

    def should_render_currency_dropdown?
      return false if current_store.nil?

      current_store.supported_currencies_list.size > 1
    end

    def currency_symbol(currency)
      ::Money::Currency.find(currency).symbol
    end

    def currency_presentation(currency)
      label = [currency_symbol(currency), currency].compact.join(' ')

      [label, currency]
    end

    def preferred_currencies
      @preferred_currencies ||= current_store.supported_currencies_list
    end

    def preferred_currencies_select_options
      preferred_currencies.map { |currency| ["#{currency.name} - #{currency.iso_code}", currency] }
    end

    def currency_money(currency = current_currency)
      ::Money::Currency.find(currency)
    end
  end
end
