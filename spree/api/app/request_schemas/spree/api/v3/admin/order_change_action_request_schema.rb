module Spree
  module Api
    module V3
      module Admin
        # One change to a placed order, as the preview and the change set
        # itself both take it.
        class OrderChangeActionRequestSchema < Spree::Api::V3::RequestSchema
          attribute :kind, :string,
            required: true,
            choices: Spree::OrderChangeAction.kinds,
            open: true,
            example: 'update_item',
            description: '`add_item` takes `variant_id` and `quantity`; `update_item` takes `line_item_id` and the new `quantity`; `remove_item` takes `line_item_id`.'
          attribute :line_item_id, :id, description: 'A line item of this order.'
          attribute :variant_id, :id, description: 'A variant of this store, for `add_item`.'
          attribute :quantity, :integer, example: 2
        end
      end
    end
  end
end
