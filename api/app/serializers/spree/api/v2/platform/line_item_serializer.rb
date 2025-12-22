module Spree
  module Api
    module V2
      module Platform
        class LineItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :tax_category, serializer: Spree.api.platform_tax_category_serializer
          belongs_to :variant, serializer: Spree.api.platform_variant_serializer

          has_many :adjustments, serializer: Spree.api.platform_adjustment_serializer
          has_many :inventory_units, serializer: Spree.api.platform_inventory_unit_serializer
          has_many :digital_links, serializer: Spree.api.platform_digital_link_serializer
        end
      end
    end
  end
end
