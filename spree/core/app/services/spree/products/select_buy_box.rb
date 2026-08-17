module Spree
  module Products
    # Picks the variant a product leads with when several sellers list it.
    #
    # A product used to have one answer to "what does this cost, is it in
    # stock, what happens when I press buy", because it had one seller. Once
    # sellers share a listing those answers become relative to a winner, and
    # this is what chooses it (docs/plans/6.0-multi-seller-marketplace.md,
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
      # @param option_value_ids [Array<Integer>, nil] narrows the candidates to
      #   variants carrying every one of these values — the "used buy box" case
      # @return [Spree::Variant, nil] nil when the product sells nothing at all
      def call(product:, currency: nil, option_value_ids: nil)
        currency ||= Spree::Current.currency
        candidates = candidates_for(product, option_value_ids)
        return success(nil) if candidates.empty?

        prices = candidates.to_h { |variant| [variant.id, variant.price_in(currency)&.amount] }
        sellable = candidates.select { |variant| sellable?(variant, prices) }

        # Nothing is buyable: rank the whole set instead, so the page still has
        # a price to show and an out-of-stock state to render against.
        success(rank(sellable.presence || candidates, prices).first)
      end

      private

      # Reads the loaded association rather than querying, so a serialized
      # product list resolves every buy box from the variants it already has.
      def candidates_for(product, option_value_ids)
        variants = product.variants.reject(&:deleted_at)
        return variants if option_value_ids.blank?

        wanted = option_value_ids.map(&:to_i).to_set
        variants.select { |variant| wanted.subset?(variant.option_values.map(&:id).to_set) }
      end

      # A seller who is suspended, still onboarding or away is not selling
      # today, so their variant cannot be what the product leads with.
      def sellable?(variant, prices)
        return false unless variant.purchasable?
        return false if prices[variant.id].nil?

        seller = variant.seller
        seller.nil? || seller.sellable?
      end

      # First-party first, then cheapest, then oldest — the last is only there
      # so two identical offers rank in a stable order rather than by whatever
      # the database returns.
      def rank(variants, prices)
        variants.sort_by do |variant|
          [
            variant.seller_id.nil? ? 0 : 1,
            prices[variant.id] || BigDecimal('Infinity'),
            variant.id
          ]
        end
      end
    end
  end
end
