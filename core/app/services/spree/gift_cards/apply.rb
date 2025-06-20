# frozen_string_literal: true
# Applies a gift card to an order
# under the hood it creates a store credit payment record and updates the gift card amount used
# @param gift_card [Spree::GiftCard] the gift card to apply
# @param order [Spree::Order] the order to apply the gift card to
# @return [Spree::Order] the order with the gift card applied
module Spree
  module GiftCards
    class Apply
      prepend Spree::ServiceModule::Base

      def call(gift_card:, order:)
        # we shouldn't mix an order with a gift card and a store credit
        return failure(:gift_card_using_store_credit_error) if order.using_store_credit?

        # we shouldn't allow a gift card to be applied to an order with a different currency
        return failure(:gift_card_mismatched_currency) if gift_card.currency != order.currency

        amount = [gift_card.amount_remaining, order.total].min
        store = order.store

        return failure(:gift_card_no_amount_remaining) unless amount.positive? || order.total.zero?

        payment_method = ensure_store_credit_payment_method!(store)

        gift_card.lock!
        order.with_lock do
          store_credit = gift_card.store_credits.create!(
            store: store,
            user: order.user,
            amount: amount,
            currency: order.currency,
            originator: gift_card,
            action_originator: gift_card
          )
          gift_card.amount_used += amount
          gift_card.save!

          order.update!(gift_card: gift_card)
          order.payments.create!(
            source: store_credit,
            payment_method: payment_method,
            amount: amount,
            state: 'checkout',
            response_code: store_credit.generate_authorization_code
          )
        end

        success(order.reload)
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
