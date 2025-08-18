module Spree
  module Api
    module V2
      module Platform
        class PromotionActionLineItemSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion_action, serializer: Spree::Api::Dependencies.platform_promotion_action_serializer.constantize
          belongs_to :variant, serializer: Spree::Api::Dependencies.platform_variant_serializer.constantize
        end
      end
    end
  end
end
