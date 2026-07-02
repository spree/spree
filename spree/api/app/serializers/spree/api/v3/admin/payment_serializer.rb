module Spree
  module Api
    module V3
      module Admin
        class PaymentSerializer < V3::PaymentSerializer
          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize amount: [:string, nullable: false], display_amount: [:string, nullable: false]

          typelize metadata: 'Record<string, unknown>',
                   captured_amount: :string,
                   order_id: [:string, nullable: true],
                   avs_response: [:string, nullable: true],
                   cvv_response_code: [:string, nullable: true],
                   cvv_response_message: [:string, nullable: true]

          attributes :metadata, :avs_response, :cvv_response_code, :cvv_response_message,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :captured_amount do |payment|
            payment.captured_amount.to_s
          end

          attribute :order_id do |payment|
            payment.order&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          one :payment_method, resource: proc { Spree.api.admin_payment_method_serializer }, if: proc { expand?('payment_method') }

          attribute :source do |payment|
            next nil if payment.source.blank?

            serializer = case payment.source_type
                         when 'Spree::CreditCard'
                           Spree.api.admin_credit_card_serializer
                         when 'Spree::StoreCredit'
                           Spree.api.admin_store_credit_serializer
                         else
                           Spree.api.admin_payment_source_serializer
                         end

            serializer.new(payment.source).to_h
          end

          one :order,
              resource: proc { Spree.api.admin_order_serializer },
              if: proc { expand?('order') }

          many :refunds,
               resource: proc { Spree.api.admin_refund_serializer },
               if: proc { expand?('refunds') }
        end
      end
    end
  end
end
