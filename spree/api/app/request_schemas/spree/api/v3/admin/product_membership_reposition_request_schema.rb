module Spree
  module Api
    module V3
      module Admin
        # Moving a product within a category's or a collection's product list.
        class ProductMembershipRepositionRequestSchema < Spree::Api::V3::RequestSchema
          publishes 'ProductMembershipRepositionParams'

          attribute :new_position, :integer,
            required: true,
            example: 0,
            description: "0-based index among the parent's products."
        end
      end
    end
  end
end
