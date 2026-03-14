# In Spree 6 this servoice will complete the Spree::Cart, and create a Spree::Order
# created based on the contents of the cart.
module Spree
  module Carts
    class Complete
      prepend Spree::ServiceModule::Base

      # Completes the cart and creates a Spree::Order based on its contents.
      # @return [Spree::Order]
      def call(cart:)
        return success(cart) if cart.completed?
        return failure(cart, 'Order is canceled') if cart.canceled?

        cart.with_lock do
          process_payments!(cart) if cart.payment_required?

          return failure(cart, cart.errors.full_messages.to_sentence) if cart.errors.any?

          advance_to_complete!(cart)

          if cart.reload.complete?
            success(cart)
          else
            failure(cart, cart.errors.full_messages.to_sentence.presence || 'Could not complete checkout')
          end
        end
      end

      private

      def process_payments!(cart)
        # If payments were already processed by the payment session
        # (e.g. Stripe charged the card during complete_payment_session),
        # skip re-processing. Only process unprocessed (checkout state) payments.
        return if cart.payment_total >= cart.total
        return if cart.payments.valid.any?(&:completed?) && cart.unprocessed_payments.empty?

        cart.process_payments!
      end

      def advance_to_complete!(cart)
        cart.next until cart.complete? || cart.errors.present?
      end
    end
  end
end
