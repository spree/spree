module Spree
  module Admin
    class PromotionActionsController < ResourceController
      include Spree::Admin::TurboFrameLayoutConcern

      belongs_to 'spree/promotion', find_by: :id

      helper_method :allowed_action_types

      before_action :set_calculator_type, only: [:new]

      private

      def model_class
        @model_class = if params.dig(:promotion_action, :type).present?
                         if allowed_action_types.map(&:to_s).include?(params.dig(:promotion_action, :type))
                           params.dig(:promotion_action, :type).safe_constantize
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
        Rails.application.config.spree.promotions.actions
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
    end
  end
end
