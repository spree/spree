module Spree
  module Api
    module V3
      class PaymentSessionSerializer < BaseSerializer
        typelize status: :string, amount: :string, currency: :string,
                 external_id: :string, external_data: 'Record<string, unknown>',
                 expires_at: [:string, nullable: true], customer_external_id: [:string, nullable: true],
                 payment_method_id: :string, order_id: :string

        attributes :status, :currency, :external_id, :external_data,
                   :customer_external_id,
                   expires_at: :iso8601, created_at: :iso8601, updated_at: :iso8601

        attribute :amount do |session|
          session.amount&.to_s
        end

        attribute :payment_method_id do |session|
          session.payment_method&.prefixed_id
        end

        attribute :order_id do |session|
          session.order&.prefixed_id
        end

        one :payment_method, resource: Spree.api.payment_method_serializer
        one :payment, resource: Spree.api.payment_serializer,
            if: proc { |session| session.payment.present? }
      end
    end
  end
end
