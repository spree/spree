module Spree
  module Api
    module V2
      module Platform
        class AdjustmentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :adjustable, polymorphic: true
          belongs_to :source, polymorphic: {
            Spree::Promotion::Actions::FreeShipping => Spree::Api::Dependencies.platform_promotion_action_serializer.constantize,
            Spree::Promotion::Actions::CreateAdjustment => Spree::Api::Dependencies.platform_promotion_action_serializer.constantize,
            Spree::Promotion::Actions::CreateItemAdjustments => Spree::Api::Dependencies.platform_promotion_action_serializer.constantize,
            Spree::Promotion::Actions::CreateLineItems => Spree::Api::Dependencies.platform_promotion_action_serializer.constantize
          }
        end
      end
    end
  end
end
