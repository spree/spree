module Spree
  module Api
    module V3
      module Admin
        class CollectionExclusionSerializer < BaseSerializer
          typelize collection_id: :string, product_id: :string

          attributes created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :collection, :product

          one :product, resource: proc { Spree.api.admin_product_serializer }, if: proc { expand?('product') }
        end
      end
    end
  end
end
