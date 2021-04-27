module Spree
  module Cart
    class PromotionsController < Spree::StoreController
      include ::Spree::CartMethods

      before_action :assign_order_with_lock

      respond_to :html

      def create
        @order.coupon_code = params[:coupon_code]
        @result = coupon_handler.new(@order).apply

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to spree.cart_path }
        end
      end

      def destroy
        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to spree.cart_path }
        end
      end

      protected

      def coupon_handler
        Spree::Dependencies.coupon_handler.constantize
      end
    end
  end
end
