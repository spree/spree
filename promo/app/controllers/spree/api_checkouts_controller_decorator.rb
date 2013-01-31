Spree::Api::CheckoutsController.class_eval do
  include Spree::Promo::ApplyCoupon

  private

  def after_update_attributes
    if object_params[:coupon_code].present?
      coupon_result = apply_coupon_code
      if !coupon_result[:coupon_applied?]
        @coupon_message = coupon_result[:error]
        respond_with(@order, :default_template => 'spree/api/orders/could_not_apply_coupon')
      end
      return true
    end
    false
  end
end
