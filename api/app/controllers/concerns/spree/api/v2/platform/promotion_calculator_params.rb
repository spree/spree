module Spree
  module Api
    module V2
      module Platform
        module PromotionCalculatorParams
          private

          def calculator_params
            [:preferred_flat_percent, :preferred_amount, :preferred_first_item, :preferred_additional_item,
             :preferred_max_items, :preferred_percent, :preferred_minimal_amount, :preferred_normal_amount,
             :preferred_discount_amount, :preferred_currency, :preferred_base_amount, :preferred_base_percent, { preferred_tiers: {} }]
          end
        end
      end
    end
  end
end
