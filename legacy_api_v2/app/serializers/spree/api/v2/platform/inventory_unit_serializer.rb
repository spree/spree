module Spree
  module Api
    module V2
      module Platform
        class InventoryUnitSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :variant, serializer: Spree.api.platform_variant_serializer
          belongs_to :shipment, serializer: Spree.api.platform_shipment_serializer
          has_many :return_items, serializer: Spree.api.platform_return_item_serializer
          has_many :return_authorizations, serializer: Spree.api.platform_return_authorization_serializer
          belongs_to :line_item, serializer: Spree.api.platform_line_item_serializer
          belongs_to :original_return_item, serializer: Spree.api.platform_return_item_serializer, type: :return_item
        end
      end
    end
  end
end
