module Spree
  # Who buys, on which channel, in which market: what a buyer can be sold, and
  # at what price, depends on all of these together. A market fixes the
  # currency and the languages a sale may use.
  class SalesContext
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :store
    attribute :market
    attribute :channel
    attribute :customer
    attribute :company
    attribute :currency, :string
    attribute :locale, :string

    validate :currency_matches_market
    validate :locale_supported_by_market

    # @param order [Spree::Order]
    # @return [Spree::SalesContext]
    def self.from_order(order)
      new(
        store: order.store, market: order.market, channel: order.channel, customer: order.customer,
        company: order.resolved_company, currency: order.currency, locale: order.locale
      )
    end

    def channel
      super || store&.default_channel
    end

    # @return [String] the requested currency, else the market's, else the store's
    def currency
      super.presence&.upcase || market&.currency || store&.default_currency
    end

    # @return [String, nil] the requested language, else the market's default
    def locale
      super.presence || market&.default_locale
    end

    # The company chosen for the sale, else the one the customer stands in
    # alone — the same answer pricing and catalog visibility reach.
    #
    # @return [Spree::Company, nil]
    def company
      chosen = super
      return chosen if chosen
      return unless customer.is_a?(Spree.customer_class) && store

      @company ||= Spree::Company.sole_standing_for(store: store, customer: customer)
    end

    # Variants the buyer may order on the channel: published there and inside
    # their catalogs.
    #
    # @return [ActiveRecord::Relation<Spree::Variant>]
    def orderable_variants
      @orderable_variants ||= Spree::Variant.for_products(
        Spree.products_for_context_service.call(
          store: store, channel: channel, customer: customer, company: company,
          base: store.products.not_discontinued_on(channel)
        ).value
      )
    end

    # Orderable variants that carry a price in the sale's currency, whether a
    # base price or one from a price list, so products sold to a buyer only
    # under their agreement are offered to that buyer.
    #
    # @return [ActiveRecord::Relation<Spree::Variant>]
    def sellable_variants
      orderable_variants.where(
        id: Spree::Price.where(currency: currency).where.not(amount: nil).select(:variant_id)
      )
    end

    private

    def currency_matches_market
      return if market.nil? || currency == market.currency

      errors.add(
        :currency, :currency_does_not_match_market,
        message: I18n.t('spree.currency_does_not_match_market', currency: market.currency)
      )
    end

    def locale_supported_by_market
      return if market.nil? || locale.blank? || market.supported_locales_list.include?(locale)

      errors.add(:locale, :locale_not_supported_by_market, message: I18n.t('spree.locale_not_supported_by_market'))
    end
  end
end
