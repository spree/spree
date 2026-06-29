module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          typelize payment_id: [:string, nullable: true],
                   refund_reason_id: [:string, nullable: true],
                   reimbursement_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          one :payment,
              resource: proc { Spree.api.admin_payment_serializer },
              if: proc { expand?('payment') }

          one :reimbursement,
              resource: proc { Spree.api.admin_reimbursement_serializer },
              if: proc { expand?('reimbursement') }
        end
      end
    end
  end
end
