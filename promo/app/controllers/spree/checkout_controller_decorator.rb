Spree::CheckoutController.class_eval do

  #TODO 90% of this method is duplicated code. DRY
  def update
    if @order.update_from_params(params)

      fire_event('spree.checkout.update')
      unless apply_coupon_code
        respond_with(@order) { |format| format.html { render :edit } }
        return
      end

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
