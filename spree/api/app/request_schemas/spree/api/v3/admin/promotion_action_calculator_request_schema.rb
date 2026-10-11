module Spree
  module Api
    module V3
      module Admin
        # The calculator of an adjustment promotion action.
        class PromotionActionCalculatorRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PromotionActionCalculatorParams'

          string :type, example: 'flat_percent_item_total',
                        description: 'The calculator kind, from `GET /promotion_actions/calculators`. Changing it swaps the calculator.'
          object :preferences, description: "Values for the calculator's settings, such as `amount` or `flat_percent`."
        end
      end
    end
  end
end
