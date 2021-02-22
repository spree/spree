module Spree
  module Admin
    module PaymentsHelper
      def payment_method_name(payment)
        payment_method = payment.payment_method

        link_to payment_method.name, spree.edit_admin_payment_method_path(payment_method)
      end
    end
  end
end
