OrdersController.class_eval do
  after_filter :clear_promotions

  def update
    @order = current_order
    if @order.update_attributes(params[:order])

      if @order.coupon_code.present?
        fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
      end

      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      fire_event('spree.order.contents_changed')
      respond_with(@order) { |format| format.html { redirect_to cart_path } }
    else
      respond_with(@order)
    end
  end

  private
  def clear_promotions
    current_order.promotion_credits.destroy_all if current_order
  end

end

