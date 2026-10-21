module Spree
  module AgentTools
    module Shopping
      # UCP `get_checkout`. Once the buyer has paid in the store's own
      # checkout this reads `completed`, carrying the order.
      class GetCheckout < Tool
        self.ucp_object = :checkout

        tool_name 'get_checkout'
        description 'Read a checkout by its id: its status and totals, until the buyer opens its continue_url.'

        param :id, required: true, description: 'The checkout id.'

        def call(id:, meta: nil)
          cart = find_cart(id)
          return not_found if cart.nil?

          present(cart)
        end

        def summary(_arguments)
          'Read the checkout'
        end
      end
    end
  end
end
