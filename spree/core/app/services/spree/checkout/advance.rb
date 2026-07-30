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

        if cart.fulfillments.empty? && cart.delivery_required? && cart.ship_address.present? && cart.respond_to?(:rebuild_fulfillments!)
          cart.rebuild_fulfillments!
        end

        if shipping_method_id.present? && cart.fulfillments.count == 1 &&
            cart.fulfillments.first.delivery_method&.id != shipping_method_id
          result = Spree::Checkout::SelectShippingMethod.call(order: cart, params: { shipping_method_id: shipping_method_id })
          return result if result.failure?
        end

        cart.recalculate_totals!
        success(cart)
      end
    end
  end
end
