module Spree
  module V2
    module Storefront
      class PaymentSerializer < BaseSerializer
        set_type :payment

        attributes :amount, :response_code, :number, :cvv_response_code, :cvv_response_message,
                   :payment_method_id, :payment_method_name
      end
    end
  end
end
