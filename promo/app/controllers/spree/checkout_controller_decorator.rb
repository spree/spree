Spree::CheckoutController.class_eval do
  include Spree::Promo::ApplyCoupon

  private

  def after_update_attributes
    if object_params[:coupon_code].present?
      coupon_result = apply_coupon_code
      unless coupon_result[:coupon_applied?]
        flash[:error] = coupon_result[:error]
        respond_with(@order) { |format| format.html { render :edit } }
        return true
      end
      flash[:success] = coupon_result[:success]
    end
    false
  end
end
