module Spree
  module Api
    module V3
      module Admin
        # Admin API Line Item Serializer
        # Extends the store serializer with metadata visibility
        class LineItemSerializer < V3::LineItemSerializer
          typelize metadata: 'Record<string, unknown> | null',
                   cost_price: [:string, nullable: true],
                   tax_category_id: [:string, nullable: true],
                   order_id: [:string, nullable: true]

          attribute :metadata do |line_item|
            line_item.metadata.presence
          end

          attribute :cost_price do |line_item|
            line_item.cost_price&.to_s
          end

          attribute :tax_category_id do |line_item|
            line_item.tax_category&.prefixed_id
          end

          attribute :order_id do |line_item|
            line_item.order&.prefixed_id
          end

          # Override inherited associations to use admin serializers
          many :option_values, resource: Spree.api.admin_option_value_serializer
          many :digital_links, resource: Spree.api.admin_digital_link_serializer

          one :order,
              resource: Spree.api.admin_order_serializer,
              if: proc { expand?('order') }

          one :variant,
              resource: Spree.api.admin_variant_serializer,
              if: proc { expand?('variant') }

          one :tax_category,
              resource: Spree.api.admin_tax_category_serializer,
              if: proc { expand?('tax_category') }

          many :adjustments,
               resource: Spree.api.admin_adjustment_serializer,
               if: proc { expand?('adjustments') }
        end
      end
    end
  end
end
