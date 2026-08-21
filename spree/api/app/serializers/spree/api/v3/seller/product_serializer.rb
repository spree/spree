module Spree
  module Api
    module V3
      module Seller
        class ProductSerializer < V3::ProductSerializer
          typelize status: :string

          attributes :status, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
