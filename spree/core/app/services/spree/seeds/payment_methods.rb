module Spree
  module Seeds
    class PaymentMethods
      prepend Spree::ServiceModule::Base
      include StoreScoped

      private

      def seed(store)
        payment_method = store.payment_methods.find_or_initialize_by(
          type: 'Spree::PaymentMethod::StoreCredit'
        )
        return if payment_method.persisted?

        payment_method.name = I18n.t('spree.store_credit_name')
        payment_method.description = I18n.t('spree.store_credit_name')
        payment_method.active = true
        payment_method.save!
      end
    end
  end
end
