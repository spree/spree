module Spree
  module Orders
    class FindCurrent
      def execute(user:, store:, **params)
        currency = params[:currency] || store.default_currency
        order = incomplete_orders(store: store, currency: currency).find_by(params)

        return order unless order.nil?
        return if user.nil?

        incomplete_orders(store: store, currency: currency).find_by(user: user).order(created_at: :desc)
      end

      private

      def incomplete_orders(store:, currency:)
        store.orders.where(currency: currency).incomplete.not_canceled.includes(scope_includes)
      end

      def scope_includes
        {
          line_items: [
            variant: [
              :images,
              option_values: :option_type,
              product: :product_properties,
            ]
          ]
        }
      end
    end
  end
end
