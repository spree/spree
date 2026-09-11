module Spree
  module Products
    # Picks the variant a product leads with when several sellers list it.
    #
    # A product used to have one answer to "what does this cost, is it in
    # stock, what happens when I press buy", because it had one seller. Once
    # sellers share a listing those answers become relative to a winner, and
    # this is what chooses it (docs/plans/6.0-multi-vendor-marketplace.md,
    # Decision 11).
    #
    # The winner is computed on every read and never stored. It turns on
    # price, stock and who is currently selling — all of which move constantly
    # — so a column would be wrong within the hour and would need invalidating
    # from every one of those places.
    #
    # Ranking is marketplace policy, not a fact about the data, so this is
    # swappable through +Spree::Dependencies.product_buy_box_service+. The
    # default ranks first-party listings ahead of sellers', then cheapest, and
    # refuses to feature anything a customer cannot actually buy. Losing
    # variants stay perfectly visible — nothing here hides them.
    #
    # Selection is keyed on the option combination, not the bare product, so a
    # product carrying a `Condition` option type has a new buy box and a used
    # one rather than one winner across both.
    class SelectBuyBox
      prepend Spree::ServiceModule::Base

      # @param product [Spree::Product]
      # @param currency [String, nil] defaults to the current store currency
      # @param option_value_ids [Array<String, Integer>, nil] narrows the candidates to
      #   variants carrying every one of these values — the "used buy box" case
      # @return [Spree::Variant, nil] nil when the product sells nothing at all
      def call(product:, currency: nil, option_value_ids: nil)
        currency ||= Spree::Current.currency
        candidates = candidates_for(product, option_value_ids)
        return success(nil) if candidates.empty?

        prices = candidates.to_h { |variant| [variant.id, variant.price_in(currency)&.amount] }
        # Anyone selling today, buyable or not — a seller who is suspended,
        # onboarding or away drops out before stock or price is considered.
        from_active_sellers = candidates.select { |variant| seller_active?(variant) }
        buyable = from_active_sellers.select { |variant| buyable?(variant, prices) }

        # Nothing is buyable: still name a variant, so the page has a price to
        # show and an out-of-stock state to render against — but from a seller
        # who is at least selling, so a suspended seller's row is never what
        # the product leads with. Only when *no* seller is active does the
        # whole set get ranked.
        pool = buyable.presence || from_active_sellers.presence || candidates
        success(rank(pool, prices).first)
      end

      private

      # Reads the loaded association rather than querying, so a serialized
      # product list resolves every buy box from the variants it already has.
      def candidates_for(product, option_value_ids)
        # Active only: an offer in review, sent back or taken down must not be
        # ranked, and must not be what the page falls back to naming when
        # nothing is buyable either
        # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
        variants = product.visible_variants
        return variants if option_value_ids.blank?

        # Compared as strings, never cast: ids may be UUIDs, and a prefixed id
        # sent straight from a request decodes to the record's real key.
        wanted = option_value_ids.map { |id| resolve_option_value_id(id) }.to_set
        variants.select { |variant| wanted.subset?(variant.option_values.map { |value| value.id.to_s }.to_set) }
      end

      # Whether the variant's seller is selling today. First-party always is.
      def seller_active?(variant)
        seller = variant.resolved_seller
        seller.nil? || seller.sellable?
      end

      # Whether a shopper could put this in a cart right now, in this currency.
      def buyable?(variant, prices)
        variant.purchasable? && !prices[variant.id].nil?
      end

      # First-party first, then cheapest, then oldest — the last is only there
      # so two identical offers rank in a stable order rather than by whatever
      # the database returns.
      def resolve_option_value_id(id)
        return Spree::OptionValue.decode_prefixed_id(id).to_s if Spree::PrefixedId.prefixed_id?(id)

        id.to_s
      end

      def rank(variants, prices)
        variants.sort_by do |variant|
          [
            variant.resolved_seller_id.nil? ? 0 : 1,
            prices[variant.id] || BigDecimal('Infinity'),
            variant.id
          ]
        end
      end
    end
  end
end
