module Spree
  module Seeds
    class PaymentMethods
      prepend Spree::ServiceModule::Base

      def call
        store = Spree::Store.default

        payment_method = Spree::PaymentMethod::StoreCredit.find_or_initialize_by(
          name: Spree.t(:store_credits),
          description: 'Store Credit',
          active: true
        )

        payment_method.stores << store if payment_method.new_record?
        payment_method.save!
      end
    end
  end
end
