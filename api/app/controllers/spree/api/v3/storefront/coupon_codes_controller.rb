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
              render json: serialize_order, status: :created
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

          protected

          def serialize_order
            serializer_class.new(@order, params: serializer_params).to_h
          end

          def serializer_params
            {
              currency: current_currency,
              store: current_store,
              user: current_user,
              locale: current_locale,
              includes: requested_includes
            }
          end
        end
      end
    end
  end
end
