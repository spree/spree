# Custom logic to be included in OrdersController.  It has intentionally been isolated in its own library to make it 
# easier for developers to customize the checkout process.
module Spree::Checkout

  def checkout
    build_object 
    load_object 
    load_data
    load_checkout_steps                                             

    if request.get?                     # default values needed for GET / first pass
      @order.bill_address ||= Address.new(:country => @default_country)
      @order.ship_address ||= Address.new(:country => @default_country) 

      if @order.creditcard.nil?
        @order.creditcard = Creditcard.new(:month => Date.today.month, :year => Date.today.year)
      end
    end

    unless request.get?                 # the proper processing
      @order.initial_shipping_method = ShippingMethod.find_by_id(params[:method_id]) if params[:method_id]  
      @method_id = params[:method_id]

      # push the current record ids into the incoming params to allow nested_attribs to do update-in-place
      if @order.bill_address && params[:order][:bill_address_attributes]
        params[:order][:bill_address_attributes][:id] = @order.bill_address.id 
      end
      if @order.ship_address && params[:order][:ship_address_attributes]
        params[:order][:bill_address_attributes][:id] = @order.bill_address.id if @order.bill_address
      end

      # and now do the over-write, saving any new changes as we go
      @order.update_attributes(params[:order])
    
      # set some derived information
      @order.user = current_user       
      @order.email = current_user.email if @order.email.blank? && current_user
      @order.ip_address = request.env['REMOTE_ADDR']
      @order.update_totals  

      begin
        # need to check valid b/c we dump the creditcard info while saving
        if @order.valid?                       
          if params[:final_answer].blank?
            @order.save
          else                                           
            # now fetch the CC info and do the authorization
            @order.creditcard = Creditcard.new params[:order][:creditcard]
            @order.creditcard.address = @order.bill_address 
            @order.creditcard.order = @order;
            @order.creditcard.authorize(@order.total)

            @order.complete
            session[:order_id] = nil 
          end
        else
          flash.now[:error] = t("unable_to_save_order")  
          render :action => "checkout" and return unless request.xhr?
        end       
      rescue Spree::GatewayError => ge
        flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        render :action => "checkout" and return 
      end
      

      respond_to do |format|
        format.html do  
          flash[:notice] = t('order_processed_successfully')
          order_params = {:checkout_complete => true}
          order_params[:order_token] = @order.token unless @order.user
          redirect_to order_url(@order, order_params)
        end
        format.js {render :json => { :order_total => number_to_currency(@order.total), 
                                     :ship_amount => number_to_currency(@order.ship_amount), 
                                     :tax_amount => number_to_currency(@order.tax_amount),
                                     :available_methods => rate_hash}.to_json,
                          :layout => false}
      end
      
    end
  end
  
  def load_checkout_steps
    @checkout_steps = %w{registration billing shipping shipping_method payment confirmation}
    @checkout_steps.delete "registration" if current_user
  end  
end
