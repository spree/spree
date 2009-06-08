class CheckoutsController < Spree::BaseController 
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  before_filter :load_data
  
  resource_controller :singleton
  belongs_to :order             
  
  layout 'application'   

  # alias original r_c method so we can handle special gateway exception that might be thrown
  alias :rc_update :update
  def update 
    begin
      rc_update
    rescue Spree::GatewayError => ge
      flash[:error] = t("unable_to_authorize_credit_card") + ": #{ge.message}"
      redirect_to edit_object_url and return
    end
  end
 
  update do
    flash nil
    
    success.wants.html do  
      flash[:notice] = t('order_processed_successfully')
      order_params = {:checkout_complete => true}
      order_params[:order_token] = @order.token unless @order.user
      session[:order_id] = nil if @order.checkout.completed_at
      redirect_to order_url(@order, order_params) and next if params[:final_answer]
    end 

    success.wants.js do   
      render :json => { :order_total => number_to_currency(@order.total), 
                        :ship_amount => number_to_currency(@order.ship_amount), 
                        :tax_amount => number_to_currency(@order.tax_amount),
                        :available_methods => rate_hash}.to_json,
             :layout => false
    end
  end
  
  update.before do
    if params[:checkout]
      # prevent double creation of addresses if user is jumping back to address stup without refreshing page
      params[:checkout][:bill_address_attributes][:id] = @checkout.bill_address.id if @checkout.bill_address
      params[:checkout][:ship_address_attributes][:id] = @checkout.ship_address.id if @checkout.ship_address
    end
    @checkout.ip_address ||= request.env['REMOTE_ADDR']
    @checkout.email ||= current_user.email if current_user
    @order.update_attribute(:user, current_user) if current_user and @order.user.blank?
  end    
    
  private
  def object
    return @object if @object
    default_country = Country.find Spree::Config[:default_country_id]
    @object = parent_object.checkout                                                  
    @object.ship_address ||= Address.new(:country => default_country)
    @object.creditcard ||= Creditcard.new(:month => Date.today.month, :year => Date.today.year)
    @object.bill_address ||= Address.new(:country => default_country)   
    @object         
  end
  
  def load_data     
    @countries = Country.find(:all).sort  
    @shipping_countries = parent_object.shipping_countries.sort
    default_country = Country.find Spree::Config[:default_country_id]
    @states = default_country.states.sort
  end
  
  def rate_hash       
    fake_shipment = Shipment.new :order => @order, :address => @order.ship_address
    @order.shipping_methods.collect do |ship_method| 
      { :id   => ship_method.id, 
        :name => ship_method.name, 
        :rate => number_to_currency(ship_method.calculate_shipping(fake_shipment)) }
    end
  end  
end