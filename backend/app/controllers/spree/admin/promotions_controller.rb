module Spree
  module Admin
    class PromotionsController < ResourceController
      before_filter :load_data

      helper 'spree/promotion_rules'

      protected
        def location_after_save
          spree.edit_admin_promotion_url(@promotion)
        end

        def load_data
          @calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
        end
    end
  end
end
