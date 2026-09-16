module Spree
  module Api
    module V3
      module Admin
        class RefundSerializer < V3::RefundSerializer
          typelize payment_id: [:string, nullable: true],
                   refund_reason_id: [:string, nullable: true],
                   refunder_id: [:string, nullable: true],
                   refunder_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # Who issued it — an admin user, or the API key an integration
          # refunded through.
          attribute :refunder_id do |refund|
            refund.refunder&.prefixed_id
          end

          attribute :refunder_type do |refund|
            Spree::Base.polymorphic_api_type(refund.refunder_type)
          end

          one :refunder,
              resource: proc { Spree.api.admin_actor_serializer },
              if: proc { expand?('refunder') }

          one :payment,
              resource: proc { Spree.api.admin_payment_serializer },
              if: proc { expand?('payment') }
        end
      end
    end
  end
end
