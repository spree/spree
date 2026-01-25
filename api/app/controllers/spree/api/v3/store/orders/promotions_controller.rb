module Spree
  module Api
    module V3
      module Store
        module Orders
          class PromotionsController < Store::ResourceController
            include Spree::Api::V3::OrderConcern

            before_action :authorize_order_access!

            # POST  /api/v3/store/orders/:order_id/promotions
            def create
              @parent.coupon_code = permitted_params[:coupon_code]

              promotion_handler.apply

              if promotion_handler.successful?
                head :no_content, status: :created
              else
                render_errors(promotion_handler.error)
              end
            end

            # DELETE  /api/v3/store/orders/:order_id/promotions/:id
            def destroy
              coupon_code = @resource.code.presence || @resource.name

              promotion_handler.remove(coupon_code)

              if promotion_handler.successful?
                head :no_content
              else
                render_errors(promotion_handler.error)
              end
            end

            protected

            def set_parent
              @parent = current_store.orders.friendly.find(params[:order_id])
            end

            def parent_association
              :order_promotions
            end

            def promotion_handler
              @promotion_handler ||= Spree::PromotionHandler::Coupon.new(@parent)
            end

            def permitted_params
              params.require(:promotion).permit(:coupon_code)
            end

            def model_class
              Spree::OrderPromotion
            end

            def serializer_class
              Spree.api.order_promotion_serializer
            end
          end
        end
      end
    end
  end
end
