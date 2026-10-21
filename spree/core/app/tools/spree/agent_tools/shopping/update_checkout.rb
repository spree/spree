module Spree
  module AgentTools
    module Shopping
      # UCP `update_checkout`: a full replacement of the checkout's line items
      # and buyer.
      class UpdateCheckout < Tool
        self.ucp_object = :checkout

        tool_name 'update_checkout'
        description 'Replace a checkout\'s contents. checkout: {line_items: [{item: {id: variant id}, quantity}], ' \
                    'buyer?: {email}}. Send every line it should hold: a line left out is removed.'
        mutating! destructive: false

        param :id, required: true, description: 'The checkout id.'
        param :checkout, type: :object, required: true, description: 'The whole checkout: every line item, and the buyer.'

        def call(id:, checkout:, meta: nil)
          update_from(find_cart(id), checkout)
        end

        def summary(_arguments)
          'Update the checkout'
        end
      end
    end
  end
end
