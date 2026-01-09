module Spree
  module Pricing
    class Resolver
      attr_reader :context

      # Initializes the resolver
      # @param context [Spree::Pricing::Context]
      def initialize(context)
        @context = context
      end

      # Returns the best price for the variant
      # @return [Spree::Price]
      def resolve
        Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
          find_best_price
        end
      end

      private

      # Returns the best price for the variant
      # @return [Spree::Price]
      def find_best_price
        # Try to find a price from applicable price lists first
        price_from_list = find_price_from_lists
        return price_from_list if price_from_list

        # Fall back to base price (no price_list_id)
        find_base_price
      end

      # Returns the price from applicable price lists
      # @return [Spree::Price]
      def find_price_from_lists
        applicable_price_lists.each do |price_list|
          price = find_price_for_list(price_list)
          return price if price
        end

        nil
      end

      # Returns the price lists that are applicable to the context
      # @return [Array<Spree::PriceList>]
      def applicable_price_lists
        @applicable_price_lists ||= begin
          lists = Spree::PriceList.includes(:price_rules)
                                   .for_context(context)
                                   .to_a

          lists.select { |list| list.applicable?(context) }
        end
      end

      # Returns the price for a given price list
      # @param price_list [Spree::PriceList]
      # @return [Spree::Price]
      def find_price_for_list(price_list)
        currency = context.currency&.upcase

        if prices.loaded?
          prices.detect do |p|
            p.currency == currency &&
              p.price_list_id == price_list.id &&
              p.amount.present? &&
              !p.amount.zero?
          end
        else
          context.variant.prices
                 .with_currency(currency)
                 .where(price_list_id: price_list.id)
                 .non_zero
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

      # Builds an empty price for the variant
      # @return [Spree::Price]
      def build_empty_price
        context.variant.prices.build(
          variant: context.variant,
          currency: context.currency,
          amount: nil,
          price_list_id: nil
        )
      end

      # Returns the cache key for the resolver
      # @return [String]
      def cache_key
        "#{context.cache_key}/resolved_price"
      end
    end
  end
end
