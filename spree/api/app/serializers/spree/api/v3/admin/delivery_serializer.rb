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

          prefixed_id_attributes :shipping_label
        end
      end
    end
  end
end
