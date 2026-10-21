module Spree
  module AgentTools
    module Shopping
      # UCP `cancel_checkout`. A completed checkout is an order, and is never
      # cancelled from here.
      class CancelCheckout < Tool
        self.ucp_object = :checkout

        tool_name 'cancel_checkout'
        description 'Cancel a checkout that has not been paid. Answers with the checkout as it was.'
        mutating!

        param :id, required: true, description: 'The checkout id.'

        def call(id:, meta: nil)
          cancel(find_cart(id))
        end

        def summary(_arguments)
          'Cancel the checkout'
        end
      end
    end
  end
end
