module Spree
  module Admin
    class PriceRulesController < ResourceController
      belongs_to 'spree/price_list', find_by: :id

      helper_method :allowed_rule_types

      private

      def model_class
        @model_class = if params.dig(:price_rule, :type).present?
                         rule_type = params.dig(:price_rule, :type)
                         rule_class = allowed_rule_types.find { |type| type.to_s == rule_type }

                         if rule_class
                           rule_class.constantize
                         else
                           raise 'Unknown price rule type'
                         end
                       else
                         Spree::PriceRule
                       end
      end

      def build_resource
        model_class.new(price_list: parent)
      end

      def allowed_rule_types
        Rails.application.config.spree.pricing.rules
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.admin_price_list_path(parent)
      end

      def permitted_resource_params
        permitted_preference_keys = @object.preferences.map do |key, value|
          if value.is_a?(Array)
            { "preferred_#{key}" => [] }
          else
            "preferred_#{key}"
          end
        end

        params.require(:price_rule).permit(:type, *permitted_preference_keys)
      end
    end
  end
end
