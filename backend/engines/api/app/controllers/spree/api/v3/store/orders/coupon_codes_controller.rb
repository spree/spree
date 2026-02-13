module Spree
  module Api
    module V3
      module Store
        module Orders
          class CouponCodesController < ResourceController
            include Spree::Api::V3::OrderConcern

            before_action :authorize_order_access!
            skip_before_action :set_resource

            # POST  /api/v3/store/orders/:order_id/coupon_codes
            # Apply a coupon code to the order
            def create
              @parent.coupon_code = permitted_params[:code]

              coupon_handler.apply

              if coupon_handler.successful?
                render json: order_serializer.new(@parent.reload, params: serializer_params).to_h, status: :created
              else
                render_errors(coupon_handler.error)
              end
            end

            # DELETE  /api/v3/store/orders/:order_id/coupon_codes/:id
            # Remove a coupon code from the order
            # :id is the promotion prefix_id (e.g., promo_xxx)
            def destroy
              @resource = scope.find_by_prefix_id!(params[:id])
              coupon_code = @resource.code.presence || @resource.name

              coupon_handler.remove(coupon_code)

              if coupon_handler.successful?
                render json: order_serializer.new(@parent.reload, params: serializer_params).to_h
              else
                render_errors(coupon_handler.error)
              end
            end

            protected

            def parent_association
              :order_promotions
            end

            def coupon_handler
              @coupon_handler ||= Spree.coupon_handler.new(@parent)
            end

            def permitted_params
              params.permit(:code)
            end

            def model_class
              Spree::OrderPromotion
            end

            def serializer_class
              Spree.api.order_promotion_serializer
            end

            def order_serializer
              Spree.api.order_serializer
            end
          end
        end
      end
    end
  end
end
