# A rule to limit a promotion based on the order's market.
module Spree
  class Promotion
    module Rules
      class Market < PromotionRule
        # Stored as raw IDs. Accepts prefixed IDs (`mkt_…`) from API
        # callers and decodes them on write so eligibility checks compare
        # against the order's raw `market_id` directly. Scope confines the
        # existence check to the promotion's store so cross-store market
        # IDs can't sneak in.
        preference :market_ids, :array, default: [],
                   parse_on_set: normalize_id_preference(
                     klass: Spree::Market,
                     scope: ->(rule) { rule.promotion&.store&.markets || Spree::Market.none }
                   )

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def markets
          return Spree::Market.none if preferred_market_ids.blank?

          promotion.store.markets.where(id: preferred_market_ids)
        end

        def eligible?(order, _options = {})
          return false if preferred_market_ids.empty?
          return true if preferred_market_ids.map(&:to_s).include?(order.market_id.to_s)

          eligibility_errors.add(:base, eligibility_error_message(:no_matching_market))
          false
        end
      end
    end
  end
end
