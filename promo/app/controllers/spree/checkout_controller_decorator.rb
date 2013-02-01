Spree::CheckoutController.class_eval do
  include Spree::Promo::ApplyCoupon

  private

  def after_update_attributes
    coupon_result = apply_coupon_code
    if coupon_result[:coupon_applied?]
      flash[:success] = coupon_result[:success]
      return false
    else
      flash[:error] = coupon_result[:error]
      respond_with(@order) { |format| format.html { render :edit } }
      return true
    end
  end
end
