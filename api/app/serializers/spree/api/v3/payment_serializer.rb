module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        attributes :id, :state, :payment_method_id, :response_code, :number, :amount, :display_amount

        one :payment_method, resource: Spree.api.v3_storefront_payment_method_serializer
      end
    end
  end
end
