module Spree
  module Admin
    class PromotionRulesController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      helper_method :allowed_rule_types

      private

      def model_class
        @model_class = if params.dig(:promotion_rule, :type).present?
                         if allowed_rule_types.map(&:to_s).include?(params.dig(:promotion_rule, :type))
                           params.dig(:promotion_rule, :type).safe_constantize
                         else
                           raise 'Unknown promotion rule type'
                         end
                       else
                         Spree::PromotionAction
                       end
      end

      def build_resource
        model_class.new(promotion: parent)
      end

      def allowed_rule_types
        Rails.application.config.spree.promotions.rules
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.admin_promotion_path(parent)
      end
    end
  end
end
