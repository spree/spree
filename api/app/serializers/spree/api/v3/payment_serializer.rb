module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        typelize_from Spree::Payment

        attributes :id, :state, :payment_method_id, :response_code, :number, :amount, :display_amount,
                   created_at: :iso8601, updated_at: :iso8601

        one :payment_method, resource: Spree.api.payment_method_serializer
      end
    end
  end
end
