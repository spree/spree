module Spree
  module Api
    module V3
      module Admin
        class OrderChangeActionSerializer < V3::BaseSerializer
          typelize kind: [:string, enum: Spree::OrderChangeAction.kinds, enum_type_name: 'OrderChangeActionKind',
                                   comment: 'What the action does to the order. Extensions may register further kinds.'],
                   line_item_id: [:string, nullable: true],
                   variant_id: [:string, nullable: true],
                   fulfillment_id: [:string, nullable: true],
                   delivery_method_id: [:string, nullable: true],
                   quantity: [:number, nullable: true],
                   discount_id: [:string, nullable: true],
                   label: [:string, nullable: true, comment: 'The discount name, for discount kinds.'],
                   value: [:string, nullable: true, comment: 'What `add_discount` takes off: an amount for `flat`, a percentage for `percent`.'],
                   value_type: [:string, nullable: true],
                   amount: [:string, nullable: true, comment: 'The new amount `update_discount` gives the row.'],
                   metadata: 'Record<string, unknown>'

          attributes :kind, :quantity, :label, :value_type, :metadata, created_at: :iso8601, updated_at: :iso8601

          attribute :value do |record|
            next if record.value.nil?
            next Spree::Money::Rounding.format_decimal(record.value) if record.value_type == 'percent'

            Spree::Money::Rounding.format(record.value, record.order_change.order.currency)
          end

          attribute :amount do |record|
            Spree::Money::Rounding.format(record.amount, record.order_change.order.currency) unless record.amount.nil?
          end

          prefixed_id_attributes :line_item, :variant, :fulfillment, :delivery_method, :discount
        end
      end
    end
  end
end
