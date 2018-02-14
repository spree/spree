module Spree
  module Admin
    class PromotionsController < ResourceController
      before_action :load_data, except: :clone

      helper 'spree/admin/promotion_rules'

      def clone
        promotion = Spree::Promotion.find(params[:id])
        duplicator = Spree::PromotionHandler::PromotionDuplicator.new(promotion)

        @new_promo = duplicator.duplicate

        if @new_promo.errors.empty?
          flash[:success] = Spree.t('promotion_cloned')
          redirect_to edit_admin_promotion_url(@new_promo)
        else
          flash[:error] = Spree.t('promotion_not_cloned', error: @new_promo.errors.full_messages.to_sentence)
          redirect_to admin_promotions_url(@new_promo)
        end
      end

      protected

      def location_after_save
        spree.edit_admin_promotion_url(@promotion)
      end

      def load_data
        @calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
        @promotion_categories = Spree::PromotionCategory.order(:name)
      end

      def collection
        return @collection if defined?(@collection)
        params[:q] ||= HashWithIndifferentAccess.new
        params[:q][:s] ||= 'id desc'

        @collection = super
        @search = @collection.ransack(params[:q])
        @collection = @search.result(distinct: true).
                      includes(promotion_includes).
                      page(params[:page]).
                      per(params[:per_page] || Spree::Config[:admin_promotions_per_page])
      end

      def promotion_includes
        [:promotion_actions]
      end
    end
  end
end
