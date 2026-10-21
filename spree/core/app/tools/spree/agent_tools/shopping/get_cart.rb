module Spree
  module AgentTools
    module Shopping
      # UCP `get_cart`: the cart as it stands now, re-priced. A cart can sit
      # for days, so an agent reads it again rather than trusting old totals.
      class GetCart < Tool
        tool_name 'get_cart'
        description 'Read a cart by its id, with current prices and totals.'

        param :id, required: true, description: 'The cart id create_cart returned.'

        def call(id:, meta: nil)
          cart = find_cart(id)
          return not_found if cart.nil?
          return already_completed if cart.completed_at.present?

          present(cart)
        end

        def summary(_arguments)
          'Read the cart'
        end
      end
    end
  end
end
