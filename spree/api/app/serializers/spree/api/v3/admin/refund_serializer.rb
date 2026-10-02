module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          typelize payment_id: [:string, nullable: true],
                   refund_reason_id: [:string, nullable: true],
                   refunder_id: [:string, nullable: true],
                   refunder_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   metadata: 'Record<string, unknown>',
                   tax_amount: :string

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # The tax inside the amount, when what was refunded carried tax.
          string_attributes :tax_amount

          # Who issued it — an admin user, or the API key an integration
          # refunded through.
          actor_attributes :refunder

          expandable :one, :payment, :admin_payment_serializer
        end
      end
    end
  end
end
