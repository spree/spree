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

        def collection
          return @collection if @collection.present?
          params[:q] ||= HashWithIndifferentAccess.new

          @collection = super
          @search = @collection.ransack(params[:q])
          @collection = @search.result(distinct: true).
            includes(promotion_includes).
            page(params[:page]).
            per(params[:per_page] || Spree::Config[:promotions_per_page])

          @collection
        end

        def promotion_includes
          [:promotion_actions]
        end
    end
  end
end
