module Spree
  module AgentTools
    module Shopping
      # UCP `get_order`: what a completed checkout became. The order carries
      # its cart's token, so the checkout id the agent already holds is the
      # order's id too — and, as with a cart, the only key to it.
      #
      # Read through the cart, so a checkout that reached several sellers
      # answers with the whole purchase rather than one seller's order.
      class GetOrder < Tool
        self.ucp_object = :order

        tool_name 'get_order'
        description 'Read an order by its id — the checkout id it was placed from — with its items, ' \
                    'what has shipped so far, and its totals.'

        param :id, required: true, description: 'The order id, which is the checkout id.'

        def call(id:, meta: nil)
          cart = find_cart(id)
          return not_found if cart.nil? || cart.completed_at.blank?

          response = purchase(cart)
          return failure(response) unless response.success?

          Ucp.order(response.data, id: cart.token, permalink_url: cart.storefront_order_url)
        end

        def summary(_arguments)
          'Read the order'
        end

        protected

        def not_found
          Ucp.error('not_found', 'No order with this id. An order exists once the buyer has paid; ' \
                                 'get_checkout says when that has happened.', :order)
        end
      end
    end
  end
end
