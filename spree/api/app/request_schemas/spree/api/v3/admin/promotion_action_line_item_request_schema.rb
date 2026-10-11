module Spree
  module Api
    module V3
      module Admin
        # A variant and quantity the `create_line_items` promotion action adds.
        class PromotionActionLineItemRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'PromotionActionLineItemParams'

          id :variant_id, required: true
          integer :quantity, required: true
        end
      end
    end
  end
end
