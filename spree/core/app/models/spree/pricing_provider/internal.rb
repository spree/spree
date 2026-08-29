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
        # chain visibility uses). A catalog-attached list applies because
        # the catalog applies — its own rules are not consulted, only its
        # status and dates.
        # @return [Array<Spree::PriceList>]
        def catalog_price_lists
          @catalog_price_lists ||= catalogs_for_context.filter_map(&:price_list).uniq.select(&:currently_active?)
        end

        # Returns the price lists that are applicable to the context.
        # Catalog-attached lists are excluded here: they are audience-scoped
        # by their catalog, and a rule-less list would otherwise apply to
        # everyone.
        # @return [Array<Spree::PriceList>]
        def applicable_price_lists
          @applicable_price_lists ||= price_lists_for_context.
                                      reject { |list| catalog_bound_price_list_ids.include?(list.id) }.
                                      select { |list| list.applicable?(context) }
        end

        # Only ACTIVE catalogs claim their list: an inactive catalog is off,
        # and blacklisting its list would silently kill a rule-based list
        # that was working before the catalog draft existed.
        def catalog_bound_price_list_ids
          @catalog_bound_price_list_ids ||=
            if context.store == Spree::Current.store
              Spree::Current.catalog_bound_price_list_ids
            elsif context.store
              Spree::Catalog.active.where(store_id: context.store.id).where.not(price_list_id: nil).
                distinct.pluck(:price_list_id).to_set
            else
              Set.new
            end
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

        # Returns the price for a given price list
        # @param price_list [Spree::PriceList]
        # @return [Spree::Price]
        def find_price_for_list(price_list)
          currency = context.currency&.upcase

          # Zero is a valid override (free for this list); only nil placeholder
          # rows (materialized by PriceList#add_products) are skipped.
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

        # Returns the base price for the variant in the current currency
        # @return [Spree::Price]
        def find_base_price
          currency = context.currency&.upcase

          price = if prices.loaded?
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

          price || build_empty_price
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
