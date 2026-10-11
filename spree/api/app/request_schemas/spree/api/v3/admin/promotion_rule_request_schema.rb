module Spree
  module Api
    module V3
      module Admin
        # The keys of a promotion rule or action beyond `type`, shared by the
        # nested promotion rule and action endpoints and by the `rules` and
        # `actions` written with a promotion. Kind-specific keys are read
        # per kind from its `additional_permitted_attributes`, so they are
        # documented here and left out of the permit list.
        class PromotionRuleRequestSchema < Spree::Api::V3::RequestSchema
          object :preferences, description: "Values for the rule kind's settings schema, from `GET /promotion_rules/types`."
          id :product_ids, array: true, permit: false, description: 'For the `product` rule.'
          id :category_ids, array: true, permit: false, description: 'For the `category` rule.'
          id :customer_ids, array: true, permit: false, description: 'For the `user` rule: the customers who qualify.'
        end
      end
    end
  end
end
