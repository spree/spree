module Spree
  module PricingProvider
    # Spree's own pricing: price lists and their rules, falling back to the
    # variant's base price. What every store uses until it connects something
    # else.
    #
    # The resolution lives here rather than in a separate Pricing::Resolver —
    # it is this provider's implementation, not a seam of its own, and having
    # two entry points invited callers to reach past the provider contract.
    # {Spree::Pricing::Context} stays where it is: it is the question every
    # provider is asked, not part of any one answer.
    class Internal < Base
      # @param context [Spree::Pricing::Context]
      # @return [Spree::Price, nil]
      def price_for(context)
        Resolution.new(context).resolve
      end

      # The price-list walk itself. A separate object because it memoizes per
      # context (+applicable_price_lists+), while a provider instance is
      # stateless and reused across calls — keeping that state here means a
      # cached provider can never serve one shopper the lists resolved for
      # another.
      class Resolution
        attr_reader :context

        # Initializes the resolver
        # @param context [Spree::Pricing::Context]
        def initialize(context)
          @context = context
        end

        # Returns the best price for the variant
        # @return [Spree::Price]
        # A price-list match wins; the base price (no price_list_id) backstops.
        def resolve
          find_price_from_lists || find_base_price
        end

        private

        # Returns the price from applicable price lists. Catalog-attached
        # lists come first — the catalog is the audience, resolved nearest
        # node first — then the rule-matched lists, then the caller falls
        # back to base.
        # @return [Spree::Price]
        def find_price_from_lists
          (catalog_price_lists + applicable_price_lists).each do |price_list|
            price = find_price_for_list(price_list)
            return price if price
          end

          nil
        end

        # Price lists reached through the buyer's effective catalogs, in
        # catalog resolution order — company subtree first, then customer
        # groups, then the channel's default catalog (the same fallback
        # chain visibility uses).
        #
        # A catalog-attached list applies because the catalog applies: its
        # audience rules are not consulted, since the assignment already
        # answered that question. Its *contextual* rules still are — a
        # VolumeRule asks about the quantity being bought, which no catalog
        # assignment can express, and that combination is what automatic
        # volume pricing is (docs/plans/6.0-price-list-automatic-pricing.md).
        # Status and dates gate the list as before.
        #
        # @return [Array<Spree::PriceList>]
        def catalog_price_lists
          @catalog_price_lists ||= catalogs_for_context.filter_map(&:price_list).uniq.select do |price_list|
            price_list.currently_active? && price_list.contextual_rules_applicable?(context)
          end
        end

        # Returns the price lists that are applicable to the context by their
        # own rules. Catalog-owned lists never appear here — the FK filter in
        # {Spree::PriceList.for_context} keeps them out in SQL, since an
        # owned list is audience-scoped by its catalog and a rule-less one
        # would otherwise apply to everyone.
        # @return [Array<Spree::PriceList>]
        def applicable_price_lists
          @applicable_price_lists ||= price_lists_for_context.
                                      select { |list| list.applicable?(context) }
        end

        # Catalogs that apply to this buyer. Reused from {Spree::Current}
        # when the context is the current store, so a product listing does
        # not re-resolve the same company / group / channel set per variant.
        # @return [Array<Spree::Catalog>]
        def catalogs_for_context
          if context.store == Spree::Current.store
            Spree::Current.catalogs_for(company: context.company, user: context.user, channel: context.channel)
          else
            Spree::Catalog.for_context(
              store: context.store, company: context.company, user: context.user, channel: context.channel
            )
          end
        end

        # Returns the price lists for the context's store
        # Uses Spree::Current.price_lists if the context matches, otherwise fetches directly
        # @return [ActiveRecord::Relation<Spree::PriceList>]
        def price_lists_for_context
          if context.store == Spree::Current.store && context.currency == Spree::Current.currency
            Spree::Current.price_lists
          else
            Spree::PriceList.for_context(context)
          end
        end

        # Returns the price for a given price list. An explicit row wins; a
        # list carrying a percentage adjustment otherwise derives one from the
        # base price.
        # @param price_list [Spree::PriceList]
        # @return [Spree::Price, nil]
        def find_price_for_list(price_list)
          explicit_price_for_list(price_list) ||
            (price_list.automatic_pricing? ? derived_price_for_list(price_list) : nil)
        end

        # An amount someone typed for this variant on this list.
        # @param price_list [Spree::PriceList]
        # @return [Spree::Price, nil]
        def explicit_price_for_list(price_list)
          currency = context.currency&.upcase

          # Zero is a valid override (free for this list); only nil placeholder
          # rows (materialized by PriceList#add_products) are skipped, so a
          # placeholder on an adjustment list falls through to the derived
          # amount rather than blocking it.
          if prices.loaded?
            prices.detect do |p|
              p.currency == currency &&
                p.price_list_id == price_list.id &&
                !p.amount.nil?
            end
          else
            context.variant.prices
                   .with_currency(currency)
                   .where(price_list_id: price_list.id)
                   .where.not(amount: nil)
                   .first
          end
        end

        # The base price times the list's factor, rounded to the currency's
        # minor unit. Built unsaved and never written: deriving on read is
        # what keeps an adjustment list from drifting when base prices move
        # (docs/plans/6.0-price-list-automatic-pricing.md).
        #
        # A variant with no base price in this currency yields nothing, so the
        # walk moves on to the next list exactly as it would for a list
        # holding no row.
        #
        # @param price_list [Spree::PriceList]
        # @return [Spree::Price, nil]
        def derived_price_for_list(price_list)
          base = base_price
          return if base.nil? || base.amount.nil?

          factor = price_list.adjustment_factor
          compare_at =
            if price_list.adjust_compare_at && base.compare_at_amount.present?
              round_for_currency(base.compare_at_amount * factor, base.currency)
            end

          Spree::Price.new(
            variant_id: context.variant.id,
            currency: base.currency,
            amount: round_for_currency(base.amount * factor, base.currency),
            compare_at_amount: compare_at,
            price_list_id: price_list.id
          )
        end

        # Rounds to the currency's own minor unit — two places for USD, none
        # for JPY — rather than assuming cents.
        # @return [BigDecimal]
        def round_for_currency(amount, currency)
          amount.round(::Money::Currency.find(currency)&.exponent || 2)
        end

        # Returns the base price for the variant in the current currency
        # @return [Spree::Price]
        def find_base_price
          base_price || build_empty_price
        end

        # The variant's own price in this currency, or nil when it has none.
        # Memoized: an adjustment list asks for it, and the base fallback may
        # ask again for the same context.
        # @return [Spree::Price, nil]
        def base_price
          return @base_price if defined?(@base_price)

          currency = context.currency&.upcase

          @base_price = if prices.loaded?
                          prices.detect do |p|
                            p.currency == currency &&
                              p.price_list_id.nil? &&
                              p.amount.present?
                          end
                        else
                          context.variant.prices
                                 .with_currency(currency)
                                 .where(price_list_id: nil)
                                 .where.not(amount: nil)
                                 .first
                        end
        end

        # Returns the prices for the variant
        # @return [ActiveRecord::Relation<Spree::Price>]
        def prices
          context.variant.prices
        end

        # Returns an empty price placeholder for the variant.
        # Uses Price.new instead of prices.build to avoid polluting the association
        # with an unsaved record that would fail validation on variant save.
        # @return [Spree::Price]
        def build_empty_price
          Spree::Price.new(
            variant_id: context.variant.id,
            # Upcased like every lookup above, so the placeholder's currency
            # cannot differ in casing from the prices it stood in for.
            currency: context.currency&.upcase,
            amount: nil,
            price_list_id: nil
          )
        end
      end
    end
  end
end
