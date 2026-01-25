module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        typelize state: :string, payment_method_id: :string, response_code: 'string | null',
                 number: :string, amount: :string, display_amount: :string

        attribute :payment_method_id do |payment|
          payment.payment_method&.prefix_id
        end

        attributes :state, :response_code, :number, :amount, :display_amount,
                   created_at: :iso8601, updated_at: :iso8601

        one :payment_method, resource: Spree.api.payment_method_serializer
      end
    end
  end
end
