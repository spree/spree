module Spree
  module Cart
    class ChangeCurrency
      prepend Spree::ServiceModule::Base

      def call(order:, new_currency:)
        return failure('Currency not supported') unless supported_currency?(order, new_currency)

        result = order.update!(currency: new_currency) rescue false

        if result
          success(order)
        else
          failure('Failed to update order')
        end
      end

      private

      def supported_currency?(order, currency)
        store = order.store
        supported_currencies = store.supported_currencies_list
        supported_currencies.map(&:iso_code).include?(currency.upcase)
      end
    end
  end
end
