module Spree
  module Pricing
    class Context
      attr_reader :variant, :currency, :store, :zone, :user, :quantity, :date, :order

      def initialize(variant:, currency:, store: nil, zone: nil, user: nil, quantity: nil, date: nil, order: nil)
        @variant = variant
        @currency = currency
        @store = store || Spree::Store.default
        @zone = zone
        @user = user
        @quantity = quantity
        @date = date || Time.current
        @order = order
      end

      def self.from_currency(variant, currency)
        new(variant: variant, currency: currency)
      end

      def self.from_order(variant, order, quantity: nil)
        new(
          variant: variant,
          currency: order.currency,
          store: order.store,
          zone: order.tax_zone || order.store.checkout_zone,
          user: order.user,
          quantity: quantity || order.line_items.find_by(variant: variant)&.quantity,
          order: order
        )
      end

      def cache_key
        [
          'spree',
          'pricing',
          variant.id,
          currency,
          store&.id,
          zone&.id,
          user&.id,
          quantity,
          date&.to_i
        ].compact.join('/')
      end
    end
  end
end
