class OrdersController < Spree::BaseController     
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  
  before_filter :prevent_editing_complete_order, :only => [:edit, :update, :checkout]            

  ssl_required :show, :checkout

  resource_controller
  actions :all, :except => :index

  layout 'application'
  
  helper :products

  create.after do    
    params[:products].each do |product_id,variant_id|
      quantity = params[:quantity].to_i if !params[:quantity].is_a?(Array)
      quantity = params[:quantity][variant_id].to_i if params[:quantity].is_a?(Array)
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:products]
    
    params[:variants].each do |variant_id, quantity|
      quantity = quantity.to_i
      @order.add_variant(Variant.find(variant_id), quantity) if quantity > 0
    end if params[:variants]
    
    @order.save
    
    # store order token in the session
    session[:order_token] = @order.token
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

  #override r_c default b/c we don't want to actually destroy, we just want to clear line items
  def destroy
    @order.line_items.clear
    respond_to do |format| 
      format.html { redirect_to(edit_object_url) } 
    end
  end  

  # feel free to override this library in your own extension
  include Spree::Checkout
  
  def can_access?
    return true unless order = load_object    
    session[:order_token] ||= params[:order_token]
    order.grant_access?(session[:order_token])
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
    load_object
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
