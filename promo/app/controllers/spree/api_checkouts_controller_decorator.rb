Spree::Api::CheckoutsController.class_eval do
  include Spree::Promo::ApplyCoupon

  # TODO: Fix this duplication
  def update
    if @order.update_attributes(object_params)
      if object_params[:coupon_code].present?
        coupon_result = apply_coupon_code
        if !coupon_result[:code_applied?]
          @coupon_message = coupon_result[:error]
          respond_with(@order, :default_template => 'spree/api/orders/could_not_apply_coupon')
          return
        end
      end
      state_callback(:after) if @order.next
      respond_with(@order, :default_template => 'spree/api/orders/show')
    else
      respond_with(@order, :default_template => 'spree/api/orders/could_not_transition', :status => 422)
    end
  end
end
