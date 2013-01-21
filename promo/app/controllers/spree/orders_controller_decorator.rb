Spree::OrdersController.class_eval do
  include Spree::Promo::ApplyCoupon

  def update
    @order = current_order
    if @order.update_attributes(params[:order])
      coupon_result = apply_coupon_code
      unless coupon_result[:coupon_applied?]
        flash[:error] = coupon_result[:error]
        render :edit
        return
      end
      flash[:success] = coupon_result[:success] if coupon_result.has_key?(:success)

      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      fire_event('spree.order.contents_changed')
      respond_with(@order) do |format|
        format.html do
          if params.has_key?(:checkout)
            redirect_to checkout_state_path(@order.checkout_steps.first)
          else
            redirect_to cart_path
          end
        end
      end
    else
      respond_with(@order)
    end
  end

end
