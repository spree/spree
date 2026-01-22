module Spree
  module Api
    module V3
      module Store
        class OrderPromotionsController < ResourceController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          # POST  /api/v3/store/orders/:order_id/order_promotions
          def create
            @order.coupon_code = permitted_params[:coupon_code]

            promotion_handler.apply

            if promotion_handler.successful?
              head :no_content, status: :created
            else
              render_errors(promotion_handler.error)
            end
          end

          # DELETE  /api/v3/store/orders/:order_id/order_promotions/:id
          def destroy
            coupon_code = @order_promotion.code.presence || @order_promotion.name

            promotion_handler.remove(coupon_code)

            if promotion_handler.successful?
              head :no_content
            else
              render_errors(promotion_handler.error)
            end
          end

          def promotion_handler
            @promotion_handler ||= Spree::PromotionHandler::Coupon.new(@order)
          end

          def permitted_params
            params.require(:order_promotion).permit(:coupon_code)
          end

          def scope
            @order.order_promotions
          end

          def model_class
            Spree::OrderPromotion
          end

          def serializer_class
            Spree.api.v3_store_order_promotion_serializer
          end
        end
      end
    end
  end
end
