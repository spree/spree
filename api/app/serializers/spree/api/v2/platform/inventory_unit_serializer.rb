module Spree
  module Api
    module V2
      module Platform
        class InventoryUnitSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize
          belongs_to :shipment, serializer: Spree::Api::Dependencies.platform_shipment_serializer.constantize
          has_many :return_items, serializer: Spree::Api::Dependencies.platform_return_item_serializer.constantize
          has_many :return_authorizations, serializer: Spree::Api::Dependencies.platform_return_authorization_serializer.constantize
          belongs_to :line_item, serializer: Spree::Api::Dependencies.platform_line_item_serializer.constantize
          belongs_to :original_return_item, serializer: Spree::Api::Dependencies.platform_return_item_serializer.constantize, type: :return_item
        end
      end
    end
  end
end
