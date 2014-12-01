module Spree
  class StoreController < Spree::BaseController
    include Spree::Core::ControllerHelpers::Order

    skip_before_action :set_current_order, only: :cart_link

    def unauthorized
      render 'spree/shared/unauthorized', layout: Spree::Config[:layout], status: 401
    end

    def cart_link
      render partial: 'spree/shared/link_to_cart'
      fresh_when(simple_current_order)
    end

    protected
      # This method is placed here so that the CheckoutController
      # and OrdersController can both reference it (or any other controller
      # which needs it)
      def apply_coupon_code
        if params[:order] && params[:order][:coupon_code]
          @order.coupon_code = params[:order][:coupon_code]

          handler = PromotionHandler::Coupon.new(@order).apply

          if handler.error.present?
            flash.now[:error] = handler.error
            respond_with(@order) { |format| format.html { render :edit } } and return
          elsif handler.success
            flash[:success] = handler.success
          end
        end
      end

      def config_locale
        Spree::Frontend::Config[:locale]
      end
  end
end
