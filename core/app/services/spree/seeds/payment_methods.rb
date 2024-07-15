module Spree
  module Seeds
    class PaymentMethods
      prepend Spree::ServiceModule::Base

      def call
        payment_method = Spree::PaymentMethod::StoreCredit.find_or_initialize_by(
          name: Spree.t(:store_credit_name),
          description: Spree.t(:store_credit_name),
          active: true
        )

        payment_method.stores = Spree::Store.all if payment_method.new_record?
        payment_method.save!
      end
    end
  end
end
