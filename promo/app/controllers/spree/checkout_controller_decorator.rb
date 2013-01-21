Spree::CheckoutController.class_eval do
  include Spree::Promo::ApplyCoupon

  #TODO 90% of this method is duplicated code. DRY
  def update
    if @order.update_attributes(object_params)

      fire_event('spree.checkout.update')
      coupon_result = apply_coupon_code
      unless coupon_result[:coupon_applied?]
        flash[:error] = coupon_result[:error]
        respond_with(@order) { |format| format.html { render :edit } }
        return
      end
      flash[:success] = coupon_result[:success]

      if @order.next
        state_callback(:after)
      else
        flash[:error] = t(:payment_processing_failed)
        respond_with(@order, :location => checkout_state_path(@order.state))
        return
      end

      if @order.state == 'complete' || @order.completed?
        flash.notice = t(:order_processed_successfully)
        flash[:commerce_tracking] = 'nothing special'
        respond_with(@order, :location => completion_route)
      else
        respond_with(@order, :location => checkout_state_path(@order.state))
      end
    else
      respond_with(@order) { |format| format.html { render :edit } }
    end
  end

end
