module Spree
  module Api
    module V3
      module Admin
        class InvoiceRequestSerializer < V3::InvoiceRequestSerializer
          typelize customer_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          attributes :metadata, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :customer

          one :billing_address, resource: proc { Spree.api.admin_address_serializer }
        end
      end
    end
  end
end
