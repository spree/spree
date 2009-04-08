class OrdersController < Spree::BaseController     
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  
  before_filter :prevent_editing_complete_order, :only => [:edit, :update]            
  before_filter :load_data, :only => :checkout

  ssl_required :show, :checkout

  resource_controller
  actions :all, :except => :index

  layout 'application'
  
  helper :products

  create.after do    
    params[:products].each do |product_id,variant_id|
      quantity = params[:quantity].to_i if !params[:quantity].is_a?(Array)
      quantity = params[:quantity][variant_id].to_i  if params[:quantity].is_a?(Array)
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:products]
    
    params[:variants].each do |variant_id, quantity|
      quantity = quantity.to_i
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:variants]
    
    @order.save
  end

  # override the default r_c behavior (remove flash - redirect to edit details instead of show)
  create do
    flash nil 
    wants.html {redirect_to edit_order_url(@order)}
  end
  
  # override the default r_c flash behavior
  update.flash nil
  update.response do |wants| 
    wants.html {redirect_to edit_order_url(object)}
  end  

  destroy do
    flash nil 
    wants.html {redirect_to new_order_url}
  end   
  
  def checkout
    build_object 
    load_object  
    
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
    
  private
  def build_object        
    @object ||= find_order
  end
  
  def object 
    return Order.find_by_number(params[:id]) if params[:id]
    find_order
  end   
  
  def prevent_editing_complete_order
    redirect_to object_url if @order.checkout_complete
  end         
  
  def load_data     
    @default_country = Country.find Spree::Config[:default_country_id]
    @countries = Country.find(:all).sort  
    @shipping_countries = @order.shipping_countries.sort  
    @states = @default_country.states.sort
  end 
  
  def rate_hash       
    shipment = @order.shipments.last
    @order.shipping_methods.collect { |ship_method| {:id => ship_method.id, 
                                                     :name => ship_method.name, 
                                                     :rate => number_to_currency(ship_method.calculate_shipping(shipment)) } }    
  end 
end
