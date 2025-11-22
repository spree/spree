module Spree
  module Admin
    class PromotionsController < ResourceController
      include PromotionsBreadcrumbConcern

      before_action :load_form_data, except: :index

      # POST /admin/promotions/:id/clone
      def clone
        promotion = current_store.promotions.find(params[:id])
        duplicator = Spree::PromotionHandler::PromotionDuplicator.new(promotion)

        @new_promo = duplicator.duplicate

        if @new_promo.errors.empty?
          flash[:success] = Spree.t('promotion_cloned')
          redirect_to spree.admin_promotion_path(@new_promo)
        else
          flash[:error] = Spree.t('promotion_not_cloned', error: @new_promo.errors.full_messages.to_sentence)
          redirect_to spree.admin_promotions_path
        end
      end

      protected

      def location_after_save
        spree.admin_promotion_path(@promotion)
      end

      def load_form_data
        @promotion_rules = Spree.promotions.rules
        @rule_types = @promotion_rules.map do |promotion_rule|
          [Spree.t("promotion_rule_types.#{promotion_rule.to_s.demodulize.underscore}.name"), promotion_rule.to_s]
        end
      end

      def collection
        return @collection if defined?(@collection)

        params[:q] ||= {}

        expired = params[:q].delete(:expired) == 'true'
        active = params[:q].delete(:active) == 'true'

        @collection = super

        @collection = @collection.active if active
        @collection = @collection.expired if expired

        @search = @collection.ransack(params[:q])
        @collection = @search.result(distinct: true).
                      includes(:promotion_actions).
                      page(params[:page]).
                      per(params[:per_page])

        params[:q][:expired] = expired
        params[:q][:active] = active

        @collection
      end

      def permitted_resource_params
        params.require(:promotion).permit(permitted_promotion_attributes)
      end
    end
  end
end
