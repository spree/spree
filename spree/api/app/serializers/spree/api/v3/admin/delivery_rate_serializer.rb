module Spree
  module Api
    module V3
      module Admin
        class DeliveryRateSerializer < V3::DeliveryRateSerializer
          typelize metadata: ['Record<string, unknown>', nullable: true]

          # Raw carrier payload (quote ids, service codes) — operational
          # detail a customer must never see.
          attributes :metadata
          attributes created_at: :iso8601, updated_at: :iso8601

          one :delivery_method, resource: proc { Spree.api.admin_delivery_method_serializer }, if: proc { expand?('delivery_method') }
        end
      end
    end
  end
end
