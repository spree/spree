module Spree
  module Api
    module V3
      module Store
        class PaymentSerializer < BaseSerializer
          attributes :id, :state, :payment_method_id, :response_code, :number, :amount, :display_amount

          one :payment_method, resource: Spree.api.v3_store_payment_method_serializer
        end
      end
    end
  end
end
