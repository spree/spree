module Spree
  module Pricing
    class Context
      attr_reader :variant, :currency, :store, :country, :market, :channel, :user, :quantity, :date, :order

      # Initializes the context
      # @param variant [Spree::Variant]
      # @param currency [String]
      # @param store [Spree::Store]
      # @param country [Spree::Country] where the buyer is taxed
      # @param market [Spree::Market]
      # @param channel [Spree::Channel]
      # @param user [Spree::User]
      # @param quantity [Integer]
      # @param date [Time]
      # @param order [Spree::Order]
      def initialize(variant: nil, currency:, store: nil, country: nil, market: nil, channel: nil, user: nil, quantity: nil, date: nil, order: nil)
        @variant = variant
        @currency = currency
        @store = store || Spree::Current.store
        @country = country || Spree::Current.tax_country
        @market = market || Spree::Current.market
        @channel = channel || Spree::Current.channel
        @user = user
        @quantity = quantity
        @date = date || Time.current
        @order = order
      end

      # The destination as a code. Rules compare against this rather than the
      # country row, so eligibility keeps working once Spree::Country is gone.
      #
      # @return [String, nil]
      def country_iso
        country&.iso
      end

      # Returns a new context from a variant and currency
      # @param variant [Spree::Variant]
      # @param currency [String]
      # @return [Spree::Pricing::Context]
      def self.from_currency(variant, currency)
        new(variant: variant, currency: currency)
      end

      # The owner's own market, not Spree::Current's: a cart carries the market it
      # was placed on, and pricing a line from the request context instead makes
      # the same cart price differently between two requests depending on whether
      # the client sent a country hint. Catalogue requests have no owner and keep
      # the Spree::Current fallback.
      def self.from_order(variant, order, quantity: nil)
        new(
          variant: variant,
          currency: order.currency,
          store: order.store,
          country: order.tax_country,
          market: order.market,
          channel: order.channel,
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
          country&.id,
          market&.id,
          channel&.id,
          user&.id,
          quantity,
          date&.to_i
        ].compact.join('/')
      end
    end
  end
end
