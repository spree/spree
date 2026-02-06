module Spree
  module Api
    module V2
      module Platform
        class PromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion_category, serializer: Spree.api.platform_promotion_category_serializer

          has_many :promotion_rules, serializer: Spree.api.platform_promotion_rule_serializer
          has_many :promotion_actions, serializer: Spree.api.platform_promotion_action_serializer
          has_many :stores, serializer: Spree.api.platform_store_serializer
        end
      end
    end
  end
end
