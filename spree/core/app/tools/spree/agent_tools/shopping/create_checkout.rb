module Spree
  module AgentTools
    module Shopping
      # UCP `create_checkout`. A Spree cart is already its own checkout, so
      # starting one from a cart answers with that same cart — which is also
      # what makes it idempotent, as the spec asks.
      class CreateCheckout < Tool
        self.ucp_object = :checkout

        tool_name 'create_checkout'
        description 'Start a checkout, from a cart (checkout: {cart_id, buyer?}) or from line items ' \
                    '(checkout: {line_items: [{item: {id: variant id}, quantity}], buyer?}). Payment is ' \
                    'taken on the store\'s own checkout page: give the buyer continue_url to finish.'
        mutating! destructive: false

        param :checkout, type: :object, required: true,
                         description: 'cart_id, or line_items; and an optional buyer: {email}.'

        def call(checkout:, meta: nil)
          payload = object(checkout)
          return invalid_argument(:checkout) if payload.nil?
          return create_from(payload) if payload[:cart_id].blank?

          cart = find_cart(payload[:cart_id])
          return not_found if cart.nil?
          return present(cart) if cart.completed_at.present? || payload[:buyer].blank?

          # The cart's contents win over any line items sent alongside it.
          update_from(cart, payload.slice(:buyer))
        end

        def summary(_arguments)
          'Start checkout'
        end
      end
    end
  end
end
