module Spree
  module Api
    module V2
      module Platform
        class AdjustmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree.api.platform_order_serializer
          belongs_to :adjustable, polymorphic: true
          belongs_to :source, polymorphic: {
            Spree::Promotion::Actions::FreeShipping => Spree.api.platform_promotion_action_serializer,
            Spree::Promotion::Actions::CreateAdjustment => Spree.api.platform_promotion_action_serializer,
            Spree::Promotion::Actions::CreateItemAdjustments => Spree.api.platform_promotion_action_serializer,
            Spree::Promotion::Actions::CreateLineItems => Spree.api.platform_promotion_action_serializer
          }
        end
      end
    end
  end
end
