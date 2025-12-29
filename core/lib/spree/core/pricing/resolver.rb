module Spree
  module Pricing
    class Resolver
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def resolve
        Rails.cache.fetch(cache_key, expires_in: 15.minutes) do
          find_best_price
        end
      end

      private

      def find_best_price
        # Try to find a price from applicable price lists first
        price_from_list = find_price_from_lists
        return price_from_list if price_from_list

        # Fall back to base price (no price_list_id)
        find_base_price
      end

      def find_price_from_lists
        applicable_price_lists.each do |price_list|
          price = find_price_for_list(price_list)
          return price if price
        end

        nil
      end

      def applicable_price_lists
        @applicable_price_lists ||= begin
          lists = Spree::PriceList.includes(:price_rules)
                                   .for_context(context)
                                   .to_a

          lists.select { |list| list.applicable?(context) }
        end
      end

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

      def prices
        context.variant.prices
      end

      def build_empty_price
        context.variant.prices.build(
          variant: context.variant,
          currency: context.currency,
          amount: nil,
          price_list_id: nil
        )
      end

      def cache_key
        "#{context.cache_key}/resolved_price"
      end
    end
  end
end
