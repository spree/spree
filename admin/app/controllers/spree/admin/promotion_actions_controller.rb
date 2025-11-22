module Spree
  module Admin
    class PromotionActionsController < ResourceController
      belongs_to 'spree/promotion', find_by: :id

      helper_method :allowed_action_types

      before_action :set_calculator_type, only: [:new]

      private

      def model_class
        @model_class = if params.dig(:promotion_action, :type).present?
                         # Find the actual class from allowed types rather than using constantize
                         action_type = params.dig(:promotion_action, :type)
                         action_class = allowed_action_types.find { |type| type.to_s == action_type }

                         if action_class
                           action_class
                         else
                           raise 'Unknown promotion action type'
                         end
                       else
                         Spree::PromotionAction
                       end
      end

      def build_resource
        model_class.new(promotion: parent)
      end

      def allowed_action_types
        Spree.promotions.actions
      end

      def location_after_save
        collection_url
      end

      def collection_url
        spree.admin_promotion_path(parent)
      end

      def set_calculator_type
        if @promotion_action.respond_to?(:calculator_type)
          @promotion_action.calculator_type = @promotion_action.class.calculators.first.name
        end
      end

      def permitted_resource_params
        params.require(:promotion_action).permit(permitted_promotion_action_attributes)
      end
    end
  end
end
