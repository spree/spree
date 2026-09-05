module Spree
  module GiftCards
    # Takes a gift card back off an order, returning the drawn-down balance to
    # the card. The reverse of Spree::GiftCards::Apply, and only possible
    # while the order is still open.
    class Remove < Spree::Workflow
      hooks :validate, :after_remove

      # @param order [Spree::Order]
      # @return [Spree::ServiceModule::Result] value is true
      def perform(order:)
        super

        step :ensure_removable
        halt!(true) if order.gift_card.nil?
        run_hooks :validate

        order.with_lock do
          # Re-checked inside the lock: the nil check above runs before it, so
          # a concurrent remove can detach the card in between and leave every
          # step below dereferencing nil.
          @gift_card = order.reload.gift_card
          next if @gift_card.nil?

          step :void_payments
          step :restore_gift_card_balance
          step :discard_store_credits
          step :detach_gift_card
          step :recalculate_order
          run_hooks :after_remove
        end

        success(true)
      end

      private

      def ensure_removable
        failure(order, :remove_gift_card_on_completed_order_error) if order.completed?
      end

      def gift_card
        @gift_card ||= order.gift_card
      end

      def payments
        @payments ||= order.payments.checkout.store_credits.where(source: gift_card.store_credits)
      end

      def void_payments
        @payment_total = payments.sum(:amount)
        payments.each(&:invalidate!)
      end

      def restore_gift_card_balance
        gift_card.with_lock do
          gift_card.amount_used -= @payment_total
          gift_card.save!
        end
      end

      # The store credits belong to the gift card rather than the order, so
      # nothing else would clean them up.
      # TODO: void these rather than destroying them.
      def discard_store_credits
        payments.each { |payment| payment.source.destroy! }
      end

      def detach_gift_card
        order.update!(gift_card: nil)
      end

      def recalculate_order
        order.recalculate_totals!
      end
    end
  end
end
