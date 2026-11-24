module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          # The Store API keeps this deprecated name until 6.5.
          _attributes.delete(:reimbursement_id)

          typelize payment_id: [:string, nullable: true],
                   refund_reason_id: [:string, nullable: true],
                   refunder_id: [:string, nullable: true],
                   refunder_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   refund_reason_name: [:string, nullable: true],
                   metadata: 'Record<string, unknown>',
                   status: [:string, enum: Spree::Refund.statuses, enum_type_name: 'RefundStatus',
                                     comment: '`requested` until the payment provider answers a refund it accepted.'],
                   failure_reason: [:string, nullable: true, comment: "The payment provider's reason, when the refund failed."]

          attributes :metadata, :status, :failure_reason,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :refund_reason_name do |refund|
            refund.reason&.name
          end

          # The tax inside the amount, when what was refunded carried tax.
          money_attributes :tax_amount
          typelize tax_amount: [:string, nullable: false]

          # Who issued it — an admin user, or the API key an integration
          # refunded through.
          actor_attributes :refunder

          one :payment,
              resource: proc { Spree.api.admin_payment_serializer },
              if: proc { expand?('payment') }
        end
      end
    end
  end
end
