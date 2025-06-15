module Spree
  module GiftCards
    class Remove
      prepend Spree::ServiceModule::Base

      def call(order:)
        return failure(:remove_gift_card_on_completed_order_error) if order.completed?
        return success(true) if order.gift_card.nil?

        gift_card = order.gift_card

        order.transaction do
          payments = order.payments.checkout.store_credits
          payment_total = payments.sum(:amount)

          payments.each(&:invalidate!)
          gift_card.undo_apply!(amount: payment_total)

          order.update_columns(gift_card_id: nil, updated_at: Time.current)
        end

        success(true)
      end
    end
  end
end
