module Spree
  module Pricing
    class Context
      attr_reader :variant, :currency, :store, :zone, :market, :user, :quantity, :date, :order

      # Initializes the context
      # @param variant [Spree::Variant]
      # @param currency [String]
      # @param store [Spree::Store]
      # @param zone [Spree::Zone]
      # @param market [Spree::Market]
      # @param user [Spree::User]
      # @param quantity [Integer]
      # @param date [Time]
      # @param order [Spree::Order]
      def initialize(variant: nil, currency:, store: nil, zone: nil, market: nil, user: nil, quantity: nil, date: nil, order: nil)
        @variant = variant
        @currency = currency
        @store = store || Spree::Current.store
        @zone = zone || Spree::Current.zone
        @market = market || Spree::Current.market
        @user = user
        @quantity = quantity
        @date = date || Time.current
        @order = order
      end

      # Returns a new context from a variant and currency
      # @param variant [Spree::Variant]
      # @param currency [String]
      # @return [Spree::Pricing::Context]
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

      # Returns the cache key for the context
      # @return [String]
      def cache_key
        [
          'spree',
          'pricing',
          variant.id,
          currency,
          store&.id,
          zone&.id,
          market&.id,
          user&.id,
          quantity,
          date&.to_i
        ].compact.join('/')
      end
    end
  end
end
