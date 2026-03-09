module Spree
  module Api
    module V3
      module Admin
        class PaymentSerializer < V3::PaymentSerializer
          typelize metadata: 'Record<string, unknown> | null',
                   captured_amount: :string,
                   order_id: [:string, nullable: true],
                   avs_response: [:string, nullable: true],
                   cvv_response_code: [:string, nullable: true],
                   cvv_response_message: [:string, nullable: true]

          attributes :avs_response, :cvv_response_code, :cvv_response_message

          attribute :metadata do |payment|
            payment.metadata.presence
          end

          attribute :captured_amount do |payment|
            payment.captured_amount.to_s
          end

          attribute :order_id do |payment|
            payment.order&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          one :payment_method, resource: Spree.api.admin_payment_method_serializer, if: proc { expand?('payment_method') }

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
              resource: Spree.api.admin_order_serializer,
              if: proc { expand?('order') }

          many :refunds,
               resource: Spree.api.admin_refund_serializer,
               if: proc { expand?('refunds') }
        end
      end
    end
  end
end
