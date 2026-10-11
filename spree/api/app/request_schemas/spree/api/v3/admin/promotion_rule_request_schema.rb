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
          attribute :preferences, :hash,
            description: "Values for the rule kind's settings schema, from `GET /promotion_rules/types`."
          attribute :product_ids, :array, of: :id, permit: false, description: 'For the `product` rule.'
          attribute :category_ids, :array, of: :id, permit: false, description: 'For the `category` rule.'
          attribute :customer_ids, :array, of: :id,
            permit: false,
            description: 'For the `user` rule: the customers who qualify.'
        end
      end
    end
  end
end
