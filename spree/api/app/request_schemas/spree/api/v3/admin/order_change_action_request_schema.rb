module Spree
  module Api
    module V3
      module Admin
        # One change to a placed order, as the preview and the change set
        # itself both take it.
        class OrderChangeActionRequestSchema < Spree::Api::V3::RequestSchema
          attribute :kind, :string,
            required: true,
            choices: Spree::OrderChangeAction::ITEM_KINDS + Spree::OrderChangeAction::DISCOUNT_KINDS,
            open: true,
            example: 'update_item',
            description: '`add_item` takes `variant_id` and `quantity`; `update_item` takes `line_item_id` and the new `quantity`; `remove_item` takes `line_item_id`. ' \
                         '`add_discount` takes `label` and `value`, with `value_type` and `line_item_id` optional; `update_discount` takes `discount_id` and a new `label` or `amount`; `remove_discount` takes `discount_id`.'
          attribute :line_item_id, :id, description: 'A line item of this order. For `add_discount`, the line the discount applies to; omitted, it is spread across the lines.'
          attribute :variant_id, :id, description: 'A variant of this store, for `add_item`.'
          attribute :quantity, :integer, example: 2
          attribute :discount_id, :id, description: 'A manual discount of this order, for `update_discount` and `remove_discount`.'
          attribute :label, :string, example: 'Customer appeasement', description: 'The discount name, for `add_discount` and `update_discount`.'
          attribute :value, :decimal, example: '10.00',
            description: 'For `add_discount`: an amount in the order currency for a `flat` discount, or a percentage for a `percent` one.'
          attribute :value_type, :string, choices: %w[flat percent], description: 'For `add_discount`. Defaults to `flat`.'
          attribute :amount, :decimal, example: '-5.00', description: 'For `update_discount`: the row\'s new amount in the order currency, zero or less.'
        end
      end
    end
  end
end
