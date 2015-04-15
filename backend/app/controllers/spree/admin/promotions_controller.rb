module Spree
  module Admin
    class PromotionsController < ResourceController
      before_action :load_data, except: [:order_promotions, :apply_to_order, :delete_from_order]
      before_action :load_order, only: [:order_promotions, :apply_to_order, :delete_from_order]
      before_action :load_promotion, only: [:apply_to_order, :delete_from_order]

      helper 'spree/promotion_rules'

      def order_promotions
        authorize! action, @order
        @promotions = @order.promotions.order("created_at ASC")

        # this is pretty heavy way to calculate @available_promotions
        # but we need to communicate to the user if there are any active
        # promotions to apply to the order.

        available_promotions_actions = []
        total_promotions_computable = 0

        Spree::Promotion.backend.active.each do |promotion|
          if promotion.active && promotion.class.order_activatable?(@order)
            available_promotions_actions += promotion.promotion_actions
          end
        end

        available_promotions_actions.each do |action|
          @order.line_items.map{ |i| total_promotions_computable += action.compute(i) }
        end if available_promotions_actions.any?

        @available_promotions = total_promotions_computable > 0 ? true : false
      end

      def apply_to_order
        if @promotion.activate(order: @order)
          update_order_totals(@order)
          flash[:success] = Spree.t(:promotion_was_succesfully_added_to_order)
        else
          flash[:error] = Spree.t(:promotion_could_not_be_added_to_order)
        end

        redirect_to admin_order_promotions_path(@order)
      end

      def delete_from_order
        @order.promotions.delete(@promotion)

        #TODO: optimize the way we find the adjustments which are created by the promotion.
        adjustment_sources = @order.all_adjustments.where(source_type: "Spree::PromotionAction").map(&:source)
        promotion_adjustments = adjustment_sources.select { |source| source.promotion_id == @promotion.id }.flat_map(&:adjustments)
        promotion_adjustments.map! { |adjustment| adjustment.delete }

        update_order_totals(@order)

        redirect_to admin_order_promotions_path(@order)
      end

      protected
        def location_after_save
          spree.edit_admin_promotion_url(@promotion)
        end

        def load_data
          @calculators = Rails.application.config.spree.calculators.promotion_actions_create_adjustments
          @promotion_categories = Spree::PromotionCategory.order(:name)
        end

        def load_order
          @order = Order.friendly.find(params[:order_id])
        end

        def load_promotion
          @promotion = Spree::Promotion.find(params[:promotion_id])
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
            per(params[:per_page] || Spree::Config[:promotions_per_page])

          @collection
        end

        def promotion_includes
          [:promotion_actions]
        end

        def update_order_totals(order)
          order.update_totals
          order.persist_totals
          order.update!
        end
    end
  end
end
