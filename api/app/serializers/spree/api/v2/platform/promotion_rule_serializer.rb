module Spree
  module Api
    module V2
      module Platform
        class PromotionRuleSerializer < BaseSerializer
          include ResourceSerializerConcern

          attribute :preferences do |promotion_rule|
            promotion_rule.preferences
          end

          belongs_to :promotion, serializer: Spree::Api::Dependencies.platform_promotion_serializer.constantize

          has_many :products, through: :product_promotion_rules, serializer: Spree::Api::Dependencies.platform_product_serializer.constantize, if: proc { |record| record.respond_to?(:product_promotion_rules) }
          has_many :users, through: :promotion_rule_users, serializer: Spree::Api::Dependencies.platform_user_serializer.constantize, if: proc { |record| record.respond_to?(:promotion_rule_users) }
          has_many :taxons, through: :promotion_rule_taxons, serializer: Spree::Api::Dependencies.platform_taxon_serializer.constantize, if: proc { |record| record.respond_to?(:promotion_rule_taxons) }
        end
      end
    end
  end
end
