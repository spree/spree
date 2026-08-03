module Spree
  module Checkout
    # Requirements-driven replacement for machine advancement: there are no
    # states to walk, so "advancing" a cart means recalculating it (prices,
    # promotions, tax, delivery proposals) so its requirements reflect the
    # latest data. The optional +shipping_method_id+ keeps the quick-checkout
    # flows working (Google Pay does not always send a separate selection).
    class Advance
      prepend Spree::ServiceModule::Base

      def call(order:, state: nil, shipping_method_id: nil)
        cart = order

        # A destination is either a shipping address or a pickup intent — a
        # pure-pickup cart never gets an address, but still needs proposals.
        has_destination = cart.ship_address.present? || cart.preferred_stock_location_id.present?
        if cart.fulfillments.empty? && cart.delivery_step_required? && has_destination && cart.respond_to?(:rebuild_fulfillments!)
          cart.rebuild_fulfillments!
        end

        if shipping_method_id.present? && cart.fulfillments.count == 1 &&
            cart.fulfillments.first.delivery_method&.id != shipping_method_id
          result = select_delivery_method(cart, shipping_method_id)
          return result if result.failure?
        end

        cart.recalculate_totals!
        success(cart)
      end

      private

      # Quick-checkout convenience: wallets (Google Pay) send the chosen
      # method alongside the address instead of as a separate selection, so
      # the rate is picked here. Normal checkout selects a rate directly on
      # the fulfillment.
      def select_delivery_method(cart, delivery_method_id)
        delivery_method = Spree::DeliveryMethod.find_by(id: delivery_method_id)
        return failure(:delivery_method_not_found) if delivery_method.nil?

        fulfillment = cart.fulfillments.first
        rate = fulfillment.delivery_rates.find_by(delivery_method: delivery_method)

        if rate.nil?
          return failure(
            :selected_delivery_method_not_found,
            "Couldn't find delivery rates for Delivery Method with ID = #{delivery_method.id} and Fulfillment with ID = #{fulfillment.id}"
          )
        end

        # Assigning the rate updates the fulfillment amount and order totals.
        fulfillment.selected_delivery_rate_id = rate.id

        success(fulfillment)
      end
    end
  end
end
