module Spree
  module Api
    module V3
      module Seller
        class DeliverySerializer < V3::DeliverySerializer
          typelize shipping_label_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :shipping_label
        end
      end
    end
  end
end
