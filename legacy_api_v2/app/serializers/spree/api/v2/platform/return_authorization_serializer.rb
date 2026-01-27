module Spree
  module Api
    module V2
      module Platform
        class ReturnAuthorizationSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :stock_location, serializer: Spree.api.platform_stock_location_serializer
          belongs_to :return_authorization_reason, object_method_name: :reason, serializer: Spree.api.platform_return_authorization_reason_serializer

          has_many :return_items, serializer: Spree.api.platform_return_item_serializer
        end
      end
    end
  end
end
