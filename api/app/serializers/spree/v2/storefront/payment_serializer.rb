module Spree
  module V2
    module Storefront
      class PaymentSerializer < BaseSerializer
        set_type :payment

        has_one :source, polymorphic: true
        has_one :payment_method

        attributes :amount, :response_code, :number, :cvv_response_code, :cvv_response_message,
                   :payment_method_id, :payment_method_name
      end
    end
  end
end
