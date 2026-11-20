module Spree
  module Api
    module V3
      module Admin
        class OrderChangeActionSerializer < V3::BaseSerializer
          typelize kind: [:string, enum: Spree::OrderChangeAction::KINDS, enum_type_name: 'OrderChangeActionKind',
                                   comment: 'What the action does to the order.'],
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

          attribute :value, &:formatted_value

          attribute :amount do |record|
            Spree::Money::Rounding.format(record.amount, record.order_change.order.currency) unless record.amount.nil?
          end

          # From the columns: a removed line or discount is gone and a deleted
          # variant is hidden, and the action still has to say which one it named.
          attribute :line_item_id do |record|
            Spree::LineItem.prefixed_id_for(record.line_item_id)
          end

          attribute :variant_id do |record|
            Spree::Variant.prefixed_id_for(record.variant_id)
          end

          attribute :discount_id do |record|
            Spree::Discount.prefixed_id_for(record.discount_id)
          end

          prefixed_id_attributes :fulfillment, :delivery_method
        end
      end
    end
  end
end
