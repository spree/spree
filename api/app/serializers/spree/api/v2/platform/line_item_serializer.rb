module Spree
  module Api
    module V2
      module Platform
        class LineItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :tax_category, serializer: Spree::Api::Dependencies.platform_tax_category_serializer.constantize
          belongs_to :variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize

          has_many :adjustments, serializer: Spree::Api::Dependencies.platform_adjustment_serializer.constantize
          has_many :inventory_units, serializer: Spree::Api::Dependencies.platform_inventory_unit_serializer.constantize
          has_many :digital_links, serializer: Spree::Api::Dependencies.platform_digital_link_serializer.constantize
        end
      end
    end
  end
end
