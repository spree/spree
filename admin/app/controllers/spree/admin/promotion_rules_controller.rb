module Spree
  module Admin
    class PromotionRulesController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      helper_method :allowed_rule_types

      private

      def model_class
        @model_class = if params.dig(:promotion_rule, :type).present?
                         # Find the actual class from allowed types rather than using constantize
                         rule_type = params.dig(:promotion_rule, :type)
                         rule_class = allowed_rule_types.find { |type| type.to_s == rule_type }

                         if rule_class
                           rule_class
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
        Spree.promotions.rules
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.admin_promotion_path(parent)
      end

      def permitted_resource_params
        params.require(:promotion_rule).permit(*permitted_promotion_rule_attributes + @object.preferences.keys.map { |key| "preferred_#{key}" })
      end
    end
  end
end
