module Spree
  module Api
    module V3
      module Admin
        class ShippingCategorySerializer < V3::ShippingCategorySerializer
          attributes created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
