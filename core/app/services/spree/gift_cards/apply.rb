module Spree
  module GiftCards
    class Apply
      prepend Spree::ServiceModule::Base

      def call(gift_card:, order:)
        return failure(:gift_card_using_store_credit_error) if order.using_store_credit?

        amount_applied = [gift_card.amount_remaining, order.total].min
        store = order.store

        gift_card.transaction do
          payment_method = ensure_store_credit_payment_method!(store)
          store_credit = gift_card.apply!(amount: amount_applied, user: order.user, currency: order.currency)

          return failure(:gift_card_no_amount_remaining) unless store_credit.present?

          order.update!(gift_card: gift_card)
          order.payments.create!(
            source: store_credit,
            payment_method: payment_method,
            amount: amount_applied,
            state: 'checkout',
            response_code: store_credit.generate_authorization_code
          )

          success(true)
        end
      end

      private

      def ensure_store_credit_payment_method!(store)
        payment_method = store.payment_methods.find_or_initialize_by(
          type: 'Spree::PaymentMethod::StoreCredit'
        )
        payment_method.name ||= Spree.t(:store_credit_name)
        payment_method.active = true
        payment_method.save! if payment_method.new_record?

        payment_method
      end
    end
  end
end
