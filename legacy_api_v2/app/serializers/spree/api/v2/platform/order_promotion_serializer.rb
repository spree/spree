module Spree
  module Api
    module V2
      module Platform
        class OrderPromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :promotion, serializer: Spree.api.platform_promotion_serializer
        end
      end
    end
  end
end
