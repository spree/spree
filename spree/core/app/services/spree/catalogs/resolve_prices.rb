module Spree
  module Catalogs
    # Answers "what does a buyer on this agreement pay for this product, and
    # where does that number come from" — the reading behind the catalog's
    # products-with-prices view (docs/plans/6.0-catalog-agreement-rework.md).
    #
    # Three sources, in the order the pricing resolver itself consults them:
    # an explicit row on the catalog's owned list, that list's percentage
    # adjustment applied to the base price, or the variant's own base price
    # when the catalog prices at base or the list says nothing about this
    # variant. A catalog whose assortment holds a product its list never
    # prices reads as `base` — which is the divergence the view exists to
    # make visible.
    #
    # No buyer is involved: an owned list applies because the catalog
    # applies, so the agreement alone decides the number. Contextual rules on
    # the list (a volume threshold) are deliberately not consulted — they ask
    # about the purchase, which a merchant reading an agreement is not making.
    #
    # Built once per page of products and reused, so a fifty-row listing is
    # two queries rather than a hundred.
    class ResolvePrices
      # @param catalog [Spree::Catalog]
      # @param currency [String] the currency to read prices in
      def initialize(catalog:, currency:)
        @catalog = catalog
        @currency = currency.to_s.upcase
      end

      # Loads the price rows every given variant needs, so callers resolving a
      # page of products pay for two queries rather than one per row.
      #
      # @param variants [Array<Spree::Variant>]
      # @return [void]
      def preload(variants)
        ids = Array(variants).map(&:id)
        return if ids.empty?

        # An empty result still counts as loaded for that variant — a product
        # nothing prices must not fall through to a query per row.
        @rows = ids.index_with { [] }.merge(price_rows_for(ids))
      end

      # The price this agreement gives for a variant.
      #
      # @param variant [Spree::Variant]
      # @return [Spree::CatalogPrice, nil] nil when nothing prices the variant
      #   in this currency at all
      def call(variant)
        rows = rows_for(variant)
        base = rows.detect { |row| row.price_list_id.nil? }

        if price_list
          explicit = rows.detect { |row| row.price_list_id == price_list.id }
          return build(explicit, 'explicit') if explicit
          return build(derive(base), 'automatic') if price_list.automatic_pricing? && base
        end

        base && build(base, 'base')
      end

      private

      attr_reader :catalog, :currency

      def price_list
        return @price_list if defined?(@price_list)

        # Only a list currently in effect prices anything; a draft or expired
        # one leaves the agreement at base, which is what a buyer would pay.
        list = catalog.price_list
        @price_list = list&.currently_active? ? list : nil
      end

      # Preloaded rows when this variant was in the batch, a query when it
      # was not: a caller who preloads a page and then asks about a variant
      # outside it must get the real answer, not silence.
      def rows_for(variant)
        preloaded = @rows&.[](variant.id)
        return preloaded if preloaded

        price_rows_for([variant.id])[variant.id] || []
      end

      # Base rows always, the owned list's rows when there is one. `compact`
      # would leave an empty list for a catalog pricing at base, and
      # `price_list_id: []` matches nothing at all.
      def price_rows_for(variant_ids)
        list_ids = [nil, price_list&.id].uniq

        Spree::Price.
          where(variant_id: variant_ids, currency: currency).
          where(price_list_id: list_ids).
          where.not(amount: nil).
          group_by(&:variant_id)
      end

      # Base × the list's factor, rounded to the currency's own minor unit —
      # the same arithmetic the pricing resolver does on read, and for the
      # same reason it is not stored.
      def derive(base)
        factor = price_list.adjustment_factor
        exponent = ::Money::Currency.find(base.currency)&.exponent || 2

        Spree::Price.new(
          variant_id: base.variant_id,
          currency: base.currency,
          amount: (base.amount * factor).round(exponent),
          price_list_id: price_list.id
        )
      end

      def build(price, source)
        Spree::CatalogPrice.new(amount: price.amount, currency: price.currency, source: source)
      end
    end
  end
end
