module Spree
  module Api
    module V3
      class PaymentSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            amount: resource.amount.to_f,
            display_amount: resource.display_amount.to_s,
            state: resource.state,
            payment_method_id: resource.payment_method_id,
            payment_method_name: resource.payment_method&.name,
            response_code: resource.response_code,
            number: resource.number,
            cvv_response_code: resource.cvv_response_code,
            cvv_response_message: resource.cvv_response_message,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
