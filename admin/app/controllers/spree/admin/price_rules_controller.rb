module Spree
  module Admin
    class PriceRulesController < ResourceController
      belongs_to 'spree/price_list', find_by: :prefix_id

      helper_method :allowed_rule_types

      private

      def model_class
        @model_class = if params.dig(:price_rule, :type).present?
                         rule_type = params.dig(:price_rule, :type)
                         rule_class = allowed_rule_types.find { |klass| klass.name.to_s == rule_type }

                         raise 'Unknown price rule type' unless rule_class

                         rule_class
                       else
                         Spree::PriceRule
                       end
      end

      def build_resource
        model_class.new(price_list: parent)
      end

      def allowed_rule_types
        Spree.pricing.rules
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
