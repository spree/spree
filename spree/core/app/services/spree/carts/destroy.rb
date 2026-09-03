module Spree
  module Carts
    class Destroy
      prepend Spree::ServiceModule::Base

      def call(cart: nil, order: nil)
        if order
          Spree::Deprecation.warn('Calling Spree::Carts::Destroy with order: is deprecated and will be removed in Spree 6.1. Pass cart: instead.')
          cart ||= order
        end
        rewrite_input!(remove: [:order], cart: cart)
        run :check_if_can_be_destroyed
        run :cancel_shipments
        run :release_gift_card
        run :void_payments
        run :clear_addresses
        run :destroy_order
      end

      private

      def check_if_can_be_destroyed(cart:)
        return failure(false, Spree.t(:cannot_be_destroyed)) unless cart&.can_be_deleted?

        success(cart: cart)
      end

      # Cart fulfillments are proposals, not commitments: nothing was picked or
      # booked, so this marks them canceled rather than running the cancel
      # workflow's restock and carrier stand-down.
      def cancel_shipments(cart:)
        cart.fulfillments.each { |fulfillment| fulfillment.update!(status: 'canceled') }

        success(cart: cart)
      end

      # Apply draws the card down while the cart is open; deleting the cart
      # must put that balance back through the same Remove path as an explicit
      # detach, not only void the checkout payment.
      def release_gift_card(cart:)
        return success(cart: cart) if cart.gift_card.blank?

        result = cart.remove_gift_card
        return failure(false, result.error) if result.failure?

        success(cart: cart)
      end

      def void_payments(cart:)
        cart.payments.each { |payment| payment.void! if payment.can_void? }

        success(cart: cart)
      end

      def clear_addresses(cart:)
        cart.ship_address = nil unless cart.ship_address&.can_be_deleted?
        cart.bill_address = nil unless cart.bill_address&.can_be_deleted?

        success(cart: cart)
      end

      def destroy_order(cart:)
        destroyed_result = cart.destroy

        return failure(false, Spree.t(:cannot_be_destroyed)) unless destroyed_result.present?

        success(cart)
      end
    end
  end
end
