module Spree
  module Admin
    class PromotionsController < ResourceController
      before_filter :load_data

      protected
        def build_resource
          @promotion = Promotion.new(params[:promotion])
          if params[:promotion] && params[:promotion][:calculator_type]
            @promotion.calculator = params[:promotion][:calculator_type].constantize.new
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
