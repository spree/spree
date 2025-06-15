module Spree
  module GiftCards
    class Apply
      prepend Spree::ServiceModule::Base

      def call(gift_card:, order:)
        return failure(:gift_card_using_store_credit_error) if order.using_store_credit?

        if order_total_below_minimum?(order.total, gift_card)
          minimum_order_amount = gift_card.display_minimum_order_amount
          return failure(:gift_card_minimum_order_value_error, minimum_order_amount: minimum_order_amount)
        end

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

      def can_apply_gift_card?(order)
        !order.using_store_credit?
      end

      def order_total_below_minimum?(order_total, gift_card)
        gift_card.minimum_order_amount.present? && gift_card.minimum_order_amount > order_total
      end

      def ensure_store_credit_payment_method!(store)
        payment_method = Spree::PaymentMethod::StoreCredit.find_or_initialize_by(
          name: 'Store Credit',
          description: 'Store Credit',
          active: true
        )

        if payment_method.new_record?
          payment_method.stores << store
          payment_method.save!
        end

        payment_method
      end
    end
  end
end
