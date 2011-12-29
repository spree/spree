Spree::CheckoutController.class_eval do
  def update
    if @order.update_attributes(object_params)

      fire_event('spree.checkout.update')

      if @order.coupon_code.present?
        # Promotion codes are stored in the preference table
        # Therefore we need to do a lookup there and find if one exists
        #
        # TODO: The ActiveRecord::Base.connection.quote_column_name stuff is a bit long...
        # TODO: Is there a better way to do that?
        if Spree::Preference.where(:value => @order.coupon_code).where("#{ActiveRecord::Base.connection.quote_column_name("key")} LIKE 'spree/promotion/code/%'").present?
          fire_event('spree.checkout.coupon_code_added', :coupon_code => @order.coupon_code)
        # If it doesn't exist, raise an error!
        # Giving them another chance to enter a valid coupon code
        else
          flash[:error] = t(:promotion_not_found)
          render :edit and return
        end
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
