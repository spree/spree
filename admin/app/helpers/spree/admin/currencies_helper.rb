module Spree
  module Admin
    module CurrenciesHelper
      def preferred_currencies
        @preferred_currencies ||= ([current_store.default_currency] + current_store.supported_currencies_list).uniq
      end

      def currency_money(currency = current_currency)
        ::Money::Currency.find(currency)
      end

      def currency_symbol(currency = current_currency)
        currency_money(currency).symbol
      end
    end
  end
end
