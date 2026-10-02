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

          string_attributes :captured_amount

          prefixed_id_attributes :order

          # Override inherited associations to use admin serializers
          expandable :one, :payment_method, :admin_payment_method_serializer

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

          expandable :one, :order, :admin_order_serializer

          expandable :many, :refunds, :admin_refund_serializer

          # How a payment made against an order group is shared between the
          # orders in it; empty on a payment made against a single order.
          expandable :many, :payment_splits, :admin_payment_split_serializer
        end
      end
    end
  end
end
