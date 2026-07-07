module Spree
  module Products
    # Aggregates the scattered preconditions for a product to actually be
    # sellable — status, channel publication windows, per-market prices,
    # purchasable stock, and per-market translations — into one checklist.
    # None of these individually failing raises or blocks a save; a merchant
    # can save an incomplete product (a draft price list, a translation still
    # in progress). This service exists so the admin can be *told* the
    # product isn't ready instead of finding out from an empty storefront
    # catalog or a customer complaint.
    #
    # @example
    #   result = Spree::Products::ReadinessCheck.call(product: product)
    #   result.ready? # => false
    #   result.checks.reject(&:ready) # => [#<Check key="price:EUR" ...>]
    class ReadinessCheck
      Check = Struct.new(:key, :ready, :message, keyword_init: true) do
        def ready?
          ready
        end
      end

      Result = Struct.new(:checks, keyword_init: true) do
        def ready?
          checks.all?(&:ready?)
        end
      end

      def self.call(product:)
        new(product).call
      end

      def initialize(product)
        @product = product
        @store = product.store || Spree::Current.store || Spree::Store.default
      end

      # @return [Result]
      def call
        Result.new(checks: [status_check, *channel_checks, *price_checks, stock_check, *translation_checks].compact)
      end

      private

      attr_reader :product, :store

      def status_check
        ready = product.status == 'active'
        Check.new(
          key: 'status',
          ready: ready,
          message: ready ? nil : "Status is \"#{product.status}\", not \"active\""
        )
      end

      def channel_checks
        channels = store&.channels.to_a
        return [Check.new(key: 'channels', ready: false, message: 'Store has no channels configured')] if channels.empty?

        channels.map do |channel|
          publication = product.publication_for(channel)
          ready = publication.present? && publication.published?
          Check.new(
            key: "channel:#{channel.code}",
            ready: ready,
            message: ready ? nil : "Not published on channel \"#{channel.name}\""
          )
        end
      end

      def price_checks
        markets = store&.markets.to_a
        return [Check.new(key: 'prices', ready: false, message: 'Store has no markets configured')] if markets.empty?

        markets.map do |market|
          currency = market.currency.to_s.upcase
          ready = product.prices_including_master.non_zero.where(currency: currency).exists?
          Check.new(
            key: "price:#{currency}",
            ready: ready,
            message: ready ? nil : "No price set in #{currency} (market \"#{market.name}\")"
          )
        end
      end

      def stock_check
        ready = product.purchasable?
        Check.new(
          key: 'stock',
          ready: ready,
          message: ready ? nil : 'No purchasable variant (out of stock and not backorderable)'
        )
      end

      def translation_checks
        locales = store&.markets.to_a.flat_map(&:supported_locales_list).uniq
        return [] if locales.empty?

        locales.map do |locale|
          ready = product.get_field_with_locale(locale, :name, fallback: false).present?
          Check.new(
            key: "translation:#{locale}",
            ready: ready,
            message: ready ? nil : "Missing #{locale} translation for name"
          )
        end
      end
    end
  end
end
