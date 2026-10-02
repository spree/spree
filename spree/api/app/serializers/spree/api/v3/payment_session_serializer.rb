module Spree
  module Api
    module V3
      class PaymentSessionSerializer < BaseSerializer
        typelize status: [:string, enum: Spree::PaymentSession.statuses, enum_type_name: 'PaymentSessionStatus'], amount: :string, currency: :string,
                 external_id: :string, external_data: 'Record<string, unknown>',
                 expires_at: [:string, nullable: true], customer_external_id: [:string, nullable: true],
                 payment_method_id: :string, order_id: [:string, nullable: true],
                 cart_id: [:string, nullable: true]

        attributes :status, :currency, :external_id, :external_data,
                   :customer_external_id,
                   expires_at: :iso8601

        attribute :amount do |session|
          session.amount&.to_s
        end

        prefixed_id_attributes :payment_method

        # Bridge: reports the owner (cart during checkout, order after
        # completion) until clients migrate to cart_id/order_id.
        prefixed_id_attributes order_id: :owner

        prefixed_id_attributes :cart

        one :payment_method, resource: proc { Spree.api.payment_method_serializer }
        one :payment, resource: proc { Spree.api.payment_serializer },
            if: proc { |session| session.payment.present? }
      end
    end
  end
end
