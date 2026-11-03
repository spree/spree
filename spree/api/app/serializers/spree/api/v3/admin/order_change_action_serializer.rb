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
                   metadata: 'Record<string, unknown>'

          attributes :kind, :quantity, :metadata, created_at: :iso8601, updated_at: :iso8601

          prefixed_id_attributes :line_item, :variant, :fulfillment, :delivery_method
        end
      end
    end
  end
end
