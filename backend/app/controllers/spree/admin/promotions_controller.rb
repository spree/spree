module Spree
  module Admin
    class PromotionsController < ResourceController
      before_action :load_data

      helper 'spree/admin/promotion_rules'

      def update
        promotion_actions_attributes = permitted_resource_params[:promotion_actions_attributes].to_h.map do |key, value|
          unless @promotion.promotion_actions.detect { |x| x.id.to_s == key && x.type == value['calculator_type'] }
            value[:calculator] = value.delete('calculator_type').constantize.new
            [key, value]
          end
        end.compact.to_h

        if @object.update_attributes(permitted_resource_params.merge('promotion_actions_attributes' => promotion_actions_attributes))
          flash[:success] = flash_message_for(@object, :successfully_updated)
          redirect_to location_after_save
        else
          render action: :edit
        end
      end

      protected

      def location_after_save
        spree.edit_admin_promotion_url(@promotion)
      end

      def load_data
        @calculators = Spree::Calculator.calculators_for(:promotion_actions_create_adjustments)
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
