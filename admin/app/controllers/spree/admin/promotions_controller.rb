module Spree
  module Admin
    class PromotionsController < ResourceController
      include PromotionsBreadcrumbConcern

      before_action :load_form_data, except: :index

      # GET /admin/promotions/select_options
      def select_options
        q = params[:q]
        ransack_params = q.is_a?(String) ? { name_i_cont: q } : q
        promotions = current_store.promotions.applied.accessible_by(current_ability).ransack(ransack_params).result.order(:name).limit(25)

        render json: promotions.pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end

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

      def collection_includes
        [:promotion_actions]
      end

      def permitted_resource_params
        params.require(:promotion).permit(permitted_promotion_attributes)
      end
    end
  end
end
