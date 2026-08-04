module Spree
  module Api
    module V3
      module Admin
        class ProductTypeSerializer < V3::ProductTypeSerializer
          typelize fulfillment_types: [:string, multi: true],
                   products_count: :number

          attributes :fulfillment_types, :products_count,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
