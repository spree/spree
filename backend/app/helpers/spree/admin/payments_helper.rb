module Spree
  module Admin
    module PaymentsHelper
      def payment_method_name(payment)
        # HACK: to allow us to retrieve the name of a "deleted" payment method
        id = payment.payment_method_id
        Spree::PaymentMethod.find_with_destroyed(id).name
      end
    end
  end
end
