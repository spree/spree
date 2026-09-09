module Spree
  module Api
    module V3
      module Seller
        class DeliverySerializer < V3::DeliverySerializer
          typelize shipping_label_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :shipping_label_id do |delivery|
            delivery.shipping_label&.prefixed_id
          end
        end
      end
    end
  end
end
