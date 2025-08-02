module Spree
  module Api
    module V2
      module Platform
        class ReturnAuthorizationSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :stock_location, serializer: Spree::Api::Dependencies.platform_stock_location_serializer.constantize
          belongs_to :return_authorization_reason, object_method_name: :reason, serializer: Spree::Api::Dependencies.platform_return_authorization_reason_serializer.constantize

          has_many :return_items, serializer: Spree::Api::Dependencies.platform_return_item_serializer.constantize
        end
      end
    end
  end
end
