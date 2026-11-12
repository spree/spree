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
    attribute :country
    attribute :currency, :string
    attribute :locale, :string
    # A placed sale keeps the company it was stamped with, even none, so only
    # a sale still being put together looks up the customer's company.
    attribute :resolve_company, :boolean, default: true

    validate :currency_sold_in_a_market
    validate :currency_matches_market
    validate :locale_supported_by_market

    # @param order [Spree::Order]
    # @return [Spree::SalesContext]
    def self.from_order(order)
      new(
        store: order.store, market: order.market, channel: order.channel, customer: order.customer,
        company: order.resolved_company, resolve_company: false, country: order.tax_country,
        currency: order.currency, locale: order.locale
      )
    end

    # The market chosen for the sale, else one selling the requested currency,
    # else the store's default.
    #
    # @return [Spree::Market, nil]
    def market
      chosen = super
      return chosen if chosen
      return @resolved_market if defined?(@resolved_market)

      @resolved_market = resolve_market
    end

    def channel
      super || store&.default_channel
    end

    # @return [String] the requested currency, else the market's, else the store's
    def currency
      requested_currency || market&.currency || store&.default_currency
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
      return chosen if chosen || !resolve_company
      return @standing_company if defined?(@standing_company)

      @standing_company =
        if customer.is_a?(Spree.customer_class) && store
          Spree::Company.sole_standing_for(store: store, customer: customer)
        end
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

    # Orderable variants the buyer can be quoted in the sale's currency: a base
    # price, or a price from a list that applies to them, so a product sold to
    # a buyer only under their agreement is offered to that buyer alone.
    #
    # @return [ActiveRecord::Relation<Spree::Variant>]
    def sellable_variants
      prices = Spree::Price.where(variant_id: orderable_variants.select(:id), currency: currency)
                           .where.not(amount: nil)
                           .where(price_list_id: [nil, *applicable_price_list_ids])

      orderable_variants.where(id: prices.select(:variant_id))
    end

    # @return [Spree::Pricing::Context] the context prices are resolved in
    def pricing_context
      @pricing_context ||= Spree::Pricing::Context.new(
        currency: currency, store: store, country: country, market: market,
        channel: channel, user: customer, company: company
      )
    end

    private

    def requested_currency
      attributes['currency'].presence&.upcase
    end

    def resolve_market
      return unless store

      candidates = [(Spree::Current.market if Spree::Current.store == store), store.default_market].compact
      return candidates.first unless requested_currency

      candidates.find { |candidate| candidate.currency == requested_currency } ||
        store.markets.find_by(currency: requested_currency)
    end

    # Catalog price lists the buyer's catalogs carry, and standalone lists
    # whose rules match the sale, judged the way the internal pricing provider
    # judges them.
    def applicable_price_list_ids
      @applicable_price_list_ids ||= begin
        catalogs = Spree::Catalog.groups_for_buyer(store: store, customer: customer, company: company, channel: channel)
        catalog_lists = catalogs.flatten.filter_map(&:price_list).select do |list|
          list.currently_active? && list.contextual_rules_applicable?(pricing_context)
        end
        standalone_lists = Spree::PriceList.for_context(pricing_context).select { |list| list.applicable?(pricing_context) }

        (catalog_lists + standalone_lists).map(&:id).uniq
      end
    end

    def currency_sold_in_a_market
      return if requested_currency.nil? || market || store.nil? || !store.markets.exists?

      errors.add(:currency, :currency_not_supported_by_store, message: I18n.t('spree.currency_not_supported_by_store'))
    end

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
