module Spree
  module Api
    module V2
      module Platform
        class PromotionSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :promotion_category, serializer: Spree::Api::Dependencies.platform_promotion_category_serializer.constantize

          has_many :promotion_rules, serializer: Spree::Api::Dependencies.platform_promotion_rule_serializer.constantize
          has_many :promotion_actions, serializer: Spree::Api::Dependencies.platform_promotion_action_serializer.constantize
          has_many :stores, serializer: Spree::Api::Dependencies.platform_store_serializer.constantize
        end
      end
    end
  end
end
