module Spree
  module Api
    module V3
      module Admin
        class DeliverySerializer < V3::DeliverySerializer
          typelize shipping_label_id: [:string, nullable: true],
                   details: ['Record<string, unknown>', nullable: true]

          # The raw carrier payload — scan history, signature, failure reason.
          # Operational detail, so admin-only.
          attributes :details, created_at: :iso8601, updated_at: :iso8601

          attribute :shipping_label_id do |delivery|
            delivery.shipping_label&.prefixed_id
          end
        end
      end
    end
  end
end
