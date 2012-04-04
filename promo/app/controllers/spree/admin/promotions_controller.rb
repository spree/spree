module Spree
  module Admin
    class PromotionsController < ResourceController
      before_filter :load_data
      helper 'spree/promotion_rules'

      protected
        def build_resource
          calculator_type = params[:promotion].delete(:calculator_type)
          @promotion = Promotion.new(params[:promotion])
          if params[:promotion] && calculator_type
            @promotion.calculator = calculator_type.constantize.new
          end
          @promotion
        end

        def location_after_save
          spree.edit_admin_promotion_url(@promotion)
        end

        def load_data
          @calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
        end
    end
  end
end
