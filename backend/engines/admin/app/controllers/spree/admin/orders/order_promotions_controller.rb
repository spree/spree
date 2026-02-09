module Spree
  module Admin
    module Orders
      class OrderPromotionsController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order
        before_action :load_order_promotion, only: :destroy

        layout 'turbo_rails/frame'

        # GET /admin/orders/:order_id/order_promotions/new
        def new; end

        # POST /admin/orders/:order_id/order_promotions
        def create
          authorize! :update, @order

          @order.coupon_code = params[:coupon_code]

          @handler = Spree::PromotionHandler::Coupon.new(@order)
          @handler.apply

          if @handler.successful?
            flash.now[:success] = @handler.success
            @order.reload
            load_order_items
          else
            flash.now[:error] = @handler.error
          end
        end

        # DELETE /admin/orders/:order_id/promotions/:id
        def destroy
          authorize! :update, @order

          coupon_code = @order_promotion.code.presence || @order_promotion.name

          @handler = Spree::PromotionHandler::Coupon.new(@order)
          @handler.remove(coupon_code)

          if @handler.successful?
            flash.now[:success] = @handler.success
            @order.reload
            load_order_items
          else
            flash.now[:error] = @handler.error
          end
        end

        private

        def load_order_promotion
          @order_promotion = @order.order_promotions.find(params[:id])
        end
      end
    end
  end
end
