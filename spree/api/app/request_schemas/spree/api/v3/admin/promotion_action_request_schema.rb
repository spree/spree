module Spree
  module Api
    module V3
      module Admin
        # The keys of a promotion action beyond `type`, shared by the promotion action endpoints and the `actions` written with a promotion.
        class PromotionActionRequestSchema < Spree::Api::V3::RequestSchema
          attribute :preferences, :hash,
            description: "Values for the action kind's settings schema, from `GET /promotion_actions/types`."
          attribute :calculator, :object, shape: Spree::Api::V3::Admin::PromotionActionCalculatorRequestSchema,
            permit: false,
            description: 'For adjustment actions.'
          attribute :line_items, :array, of: Spree::Api::V3::Admin::PromotionActionLineItemRequestSchema,
            permit: false,
            description: 'For `create_line_items`: the variants to add and their quantities. Variants left out are removed.'
        end
      end
    end
  end
end
