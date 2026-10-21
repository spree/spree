module Spree
  module AgentTools
    module Shopping
      # UCP `update_cart`: a full replacement of the cart's contents.
      class UpdateCart < Tool
        tool_name 'update_cart'
        description 'Replace a cart\'s contents. cart: {line_items: [{item: {id: variant id}, quantity}], buyer?}. ' \
                    'Send every line the cart should hold: a line left out is removed.'
        mutating! destructive: false

        param :id, required: true, description: 'The cart id.'
        param :cart, type: :object, required: true, description: 'The whole cart: every line item, and the buyer.'

        def call(id:, cart:, meta: nil)
          update_from(find_cart(id), cart)
        end

        def summary(_arguments)
          'Update the cart'
        end
      end
    end
  end
end
