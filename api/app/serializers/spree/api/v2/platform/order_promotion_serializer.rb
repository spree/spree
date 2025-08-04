module Spree
  module Api
    module V2
      module Platform
        class OrderPromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :promotion, serializer: Spree::Api::Dependencies.platform_promotion_serializer.constantize
        end
      end
    end
  end
end
