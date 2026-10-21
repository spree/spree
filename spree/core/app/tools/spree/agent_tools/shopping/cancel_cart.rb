module Spree
  module AgentTools
    module Shopping
      # UCP `cancel_cart`: abandons the cart.
      class CancelCart < Tool
        tool_name 'cancel_cart'
        description 'Cancel a cart. Answers with the cart as it was; its id stops working.'
        mutating!

        param :id, required: true, description: 'The cart id.'

        def call(id:, meta: nil)
          cancel(find_cart(id))
        end

        def summary(_arguments)
          'Cancel the cart'
        end
      end
    end
  end
end
