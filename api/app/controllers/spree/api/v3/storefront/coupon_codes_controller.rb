module Spree
  module Api
    module V3
      module Storefront
        class CouponCodesController < BaseController
          include Spree::Api::V3::OrderConcern

          before_action :set_order
          before_action :authorize_order_access!

          # POST /api/v3/storefront/orders/:order_id/coupon_codes
          def create
            @order.coupon_code = params[:coupon_code]

            if @order.save
              render json: serialize_resource(@order), status: :created
            else
              render_errors(@order.errors)
            end
          end

          # DELETE /api/v3/storefront/orders/:order_id/coupon_codes/:id
          def destroy
            @order.coupon_code = nil

            if @order.save
              head :no_content
            else
              render_errors(@order.errors)
            end
          end
        end
      end
    end
  end
end
