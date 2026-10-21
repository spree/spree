module Spree
  module AgentTools
    module Shopping
      # UCP `create_cart`.
      class CreateCart < Tool
        tool_name 'create_cart'
        description 'Create a cart. cart: {line_items: [{item: {id: variant id}, quantity}], buyer?: {email}}. ' \
                    'The answer\'s id is the only key to this cart: keep it for every later call.'
        mutating! destructive: false

        param :cart, type: :object, required: true, description: 'The cart: line_items and an optional buyer.'

        def call(cart:, meta: nil)
          create_from(cart)
        end

        def summary(_arguments)
          'Create a cart'
        end
      end
    end
  end
end
