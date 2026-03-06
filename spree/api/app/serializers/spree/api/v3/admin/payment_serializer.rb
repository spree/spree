module Spree
  module Api
    module V3
      module Admin
        class PaymentSerializer < V3::PaymentSerializer
          typelize metadata: 'Record<string, unknown> | null',
                   captured_amount: :string, order_id: [:string, nullable: true]

          attribute :metadata do |payment|
            payment.metadata.presence
          end

          attribute :captured_amount do |payment|
            payment.captured_amount.to_s
          end

          attribute :order_id do |payment|
            payment.order&.prefixed_id
          end
        end
      end
    end
  end
end
