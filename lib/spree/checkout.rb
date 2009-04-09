# Custom logic to be included in OrdersController.  It has intentionally been isolated in its own library to make it 
# easier for developers to customize the checkout process.
module Spree::Checkout

  def checkout
    build_object 
    load_object 
    load_data                                             
    
    @checkout_steps = %w{registration billing shipping shipping_method payment confirmation}
    
    # additional default values needed for checkout
    @order.bill_address ||= Address.new(:country => @default_country)
    @order.ship_address ||= Address.new(:country => @default_country)
    if @order.creditcards.empty?
      @order.creditcards.build(:month => Date.today.month, :year => Date.today.year)
    end
    @shipping_method = ShippingMethod.find_by_id(params[:method_id]) if params[:method_id]  
    @shipping_method ||= @order.shipping_methods.first    
    @order.shipments.build(:address => @order.ship_address, :shipping_method => @shipping_method)      

    if request.put?                           
      @order.creditcards.clear
      @order.attributes = params[:order]
      @order.creditcards[0].address = @order.bill_address if @order.creditcards.present?
      @order.user = current_user       
      @order.ip_address = request.env['REMOTE_ADDR']
      @order.update_totals

      begin
        # need to check valid b/c we dump the creditcard info while saving
        if @order.valid?                       
          if params[:final_answer].blank?
            @order.save
          else                                           
            @order.creditcards[0].authorize(@order.total)
            @order.complete
            # remove the order from the session
            session[:order_id] = nil 
          end
        else
          flash.now[:error] = t("unable_to_save_order")  
          render :action => "checkout" and return unless request.xhr?
        end       
      rescue Spree::GatewayError => ge
        flash.now[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
        render :action => "new" and return 
      end
      
      respond_to do |format|
        format.html {redirect_to order_url(@order, :checkout_complete => true) }
        format.js {render :json => { :order => {:order_total => @order.total, 
                                                :ship_amount => @order.ship_amount, 
                                                :tax_amount => @order.tax_amount},
                                     :available_methods => rate_hash}.to_json,
                          :layout => false}
      end
      
    end
  end
  
end