module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          typelize payment_id: [:string, nullable: true],
                   refund_reason_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          one :payment,
              resource: proc { Spree.api.admin_payment_serializer },
              if: proc { expand?('payment') }
        end
      end
    end
  end
end
