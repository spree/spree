module Spree
  module CurrencyHelper
    # Returns the list of all currencies as options for a select field.
    # By default the value is the default currency of the default store.
    # @param selected_value [String] the selected value
    # @return [String] the options for a select field
    def currency_options(selected_value = nil)
      selected_value ||= Spree::Store.default.default_currency
      currencies = ::Money::Currency.table.map do |_code, details|
        currency_presentation(details[:iso_code])
      end
      options_from_collection_for_select(currencies, :last, :first, selected_value)
    end

    # Returns the list of supported currencies for the current store as options for a select field.
    # @return [String] the options for a select field
    def supported_currency_options
      return if current_store.nil?

      @supported_currency_options ||= current_store.supported_currencies_list.map(&:iso_code).map { |currency| currency_presentation(currency) }
    end

    def should_render_currency_dropdown?
      return false if current_store.nil?

      current_store.supported_currencies_list.size > 1
    end

    # Returns the currency symbol for the given currency.
    # @param currency [String] the currency ISO code
    # @return [String] the currency symbol
    def currency_symbol(currency)
      ::Money::Currency.find(currency).symbol
    end

    # @param currency [String] the currency ISO code
    # @return [Array] the currency presentation and ISO code
    def currency_presentation(currency)
      currency_money = currency_money(currency)
      label = "#{currency_money.name} (#{currency_money.iso_code})"

      [label, currency]
    end

    # Returns the list of supported currencies for the current store.
    # @return [Array<Money::Currency>] the list of supported currencies
    def preferred_currencies
      Spree::Deprecation.warn('preferred_currencies is deprecated and will be removed in Spree 5.5. Use current_store.supported_currencies_list instead.')
      @preferred_currencies ||= current_store.supported_currencies_list
    end

    def preferred_currencies_select_options
      Spree::Deprecation.warn('preferred_currencies_select_options is deprecated and will be removed in Spree 5.5. Use supported_currency_options instead.')
      preferred_currencies.map { |currency| currency_presentation(currency) }
    end

    def currency_money(currency = current_currency)
      ::Money::Currency.find(currency)
    end
  end
end
