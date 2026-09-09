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
    # Nor is the catalog's own `active` flag. This answers "what will this
    # agreement charge", not "what is anyone paying right now": a catalog is
    # born inactive and is priced before it goes live, so reporting base
    # prices while it is a draft would show every row undiscounted beside a
    # pricing card promising a percentage — exactly when checking the
    # agreement matters most. What an active catalog charges a real buyer is
    # `PricingProvider::Internal`'s question, and its specs pin the two
    # together.
    #
    # Built once per page of products and reused, so a fifty-row listing is
    # two queries rather than a hundred.
    #
    # Built from a catalog, the list read is the catalog's own and only while
    # it is in effect — a draft or expired list leaves the agreement at base.
    # Built from a price list directly, that list is read as it stands: the
    # caller is the list's own editor, where a merchant pricing a draft has
    # to see the rows they are typing (docs/plans/6.0-volume-pricing.md).
    class ResolvePrices
      # @param catalog [Spree::Catalog, nil] the agreement to read, through its list
      # @param price_list [Spree::PriceList, nil] a list to read as-is; one of the two
      # @param currency [String] the currency to read prices in
      def initialize(currency:, catalog: nil, price_list: nil)
        raise ArgumentError, 'pass a catalog or a price list' if catalog.nil? && price_list.nil?

        @catalog = catalog
        @price_list = price_list unless price_list.nil?
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

        # Accumulated rather than replaced: a caller may preload in batches,
        # and overwriting would send every variant from an earlier batch back
        # to a query of its own.
        #
        # An empty result still counts as loaded for that variant — a product
        # nothing prices must not fall through to a query per row.
        @rows = (@rows || {}).merge(ids.index_with { [] }).merge(price_rows_for(ids))
      end

      # The price this agreement gives for a variant.
      #
      # @param variant [Spree::Variant, nil]
      # @return [Spree::CatalogPrice, nil] nil when nothing prices the variant
      #   in this currency at all, or when there is no variant to price — a
      #   product whose only variant was soft-deleted still has to render as a
      #   row rather than taking the whole listing down with it
      def call(variant)
        return if variant.nil?

        rows = rows_for(variant)
        base = rows.detect { |row| row.price_list_id.nil? }

        if price_list
          list_rows = rows.select { |row| row.price_list_id == price_list.id }
          break_count = list_rows.count { |row| row.min_quantity.to_i > 1 }
          # The bottom rung only — this reading makes no purchase, so a deeper
          # rung read as the single-unit price would name an amount the
          # resolver does not charge at that quantity. A ladder starting above
          # one unit therefore reads as base here, which is what a buyer of
          # one actually pays.
          explicit = list_rows.detect { |row| row.min_quantity.to_i == 1 }
          return build(explicit, 'explicit', tiers: break_tiers(list_rows), variant: variant) if explicit

          # Derived by the list itself, so the amount a merchant reads here is
          # the one the pricing resolver charges — one formula, not two. A
          # variant with a ladder is priced by the ladder alone, so the list's
          # percentage is not reported for it either.
          derived = price_list.automatic_pricing? && break_count.zero? ? price_list.derived_price_from(base, 1) : nil
          return build(derived, 'automatic', tiers: band_tiers(base), variant: variant) if derived

          # A list that prices this variant only from a quantity up charges
          # the base price for a single unit, and says so — with the tiers
          # counted, so the reading is "base now, less from a case up" rather
          # than a bare base price that hides the agreement.
          tiers_above = break_count.positive? ? break_tiers(list_rows) : band_tiers(base)
          return build(base, 'base', tiers: tiers_above, variant: variant) if base && tiers_above.any?
        end

        base && build(base, 'base', variant: variant)
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

      # The variant's own rungs above its ordinary price, as the agreement
      # reads them: each carries the amount it is charged at.
      #
      # @param list_rows [Array<Spree::Price>]
      # @return [Array<Spree::CatalogPriceTier>]
      def break_tiers(list_rows)
        list_rows.
          select { |row| row.min_quantity.to_i > 1 }.
          sort_by { |row| row.min_quantity.to_i }.
          map do |row|
            Spree::CatalogPriceTier.new(
              min_quantity: row.min_quantity, amount: row.amount, currency: currency
            )
          end
      end

      # The list's percentage bands, resolved against the base price — so the
      # reading is an amount a buyer pays rather than a percentage a merchant
      # has to apply in their head.
      #
      # Loaded rather than counted: this is asked once per product row, and
      # `.size` on an unloaded association issues a COUNT every time without
      # ever populating it.
      #
      # @param base [Spree::Price, nil]
      # @return [Array<Spree::CatalogPriceTier>]
      def band_tiers(base)
        return [] if price_list.nil? || base.nil?

        price_list.price_adjustment_tiers.to_a.sort_by(&:min_quantity).filter_map do |band|
          derived = price_list.derived_price_from(base, band.min_quantity)
          next if derived.nil?

          Spree::CatalogPriceTier.new(
            min_quantity: band.min_quantity, amount: derived.amount, currency: currency
          )
        end
      end

      def build(price, source, tiers: [], variant: nil)
        Spree::CatalogPrice.new(
          amount: price.amount, currency: price.currency, source: source,
          break_count: tiers.size, tiers: tiers, variant: variant
        )
      end
    end
  end
end
