Spree::OrdersController.class_eval do

  def update
    @order = current_order
    if @order.update_attributes(params[:order])
      if @order.coupon_code.present?
        unless apply_coupon_code
          flash[:error] = t(:promotion_not_found)
          render :edit and return
        end
      end
      @order.line_items = @order.line_items.select {|li| li.quantity > 0 }
      fire_event('spree.order.contents_changed')
      respond_with(@order) { |format| format.html { redirect_to cart_path } }
    else
      respond_with(@order)
    end
  end

  def apply_coupon_code
    return if @order.coupon_code.blank?
    if Spree::Promotion.exists?(:code => @order.coupon_code)
      fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
    end
  end

end
