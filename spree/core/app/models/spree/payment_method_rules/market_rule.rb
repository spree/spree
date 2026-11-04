module Spree
  module PaymentMethodRules
    # Offers the method only in the listed markets. Also how a store runs two
    # accounts of one provider: one payment method per account, each with its
    # own markets.
    class MarketRule < Spree::PaymentMethodRule
      preference :market_ids, :array, of: :id, model: 'Spree::Market', default: [],
                 scope: ->(rule) { rule.store.markets }

      def eligible?(purchase)
        return true if preferred_market_ids.empty?

        preferred_market_ids.map(&:to_s).include?(purchase.market_id.to_s)
      end
    end
  end
end
