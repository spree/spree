module Spree
  module Api
    module V2
      module Platform
        module PromotionRuleParams
          private

          def rule_params
            [:preferred_match_policy, :preferred_country_id, :preferred_amount_min, :preferred_operator_min, :preferred_amount_max,
             :preferred_operator_max, { taxon_ids: [], user_ids: [], product_ids: [], preferred_eligible_values: {} }]
          end
        end
      end
    end
  end
end
