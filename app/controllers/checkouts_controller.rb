class CheckoutsController < Spree::BaseController 
  include ActionView::Helpers::NumberHelper # Needed for JS usable rate information
  before_filter :load_data
  
  resource_controller :singleton
  belongs_to :order             
  
  layout 'application'   
  ssl_required :update, :edit

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
      if current_user
        current_user.update_attribute(:bill_address, @order.bill_address)
        current_user.update_attribute(:ship_address, @order.ship_address)
      end
      flash[:notice] = t('order_processed_successfully')
      order_params = {:checkout_complete => true}
      order_params[:order_token] = @order.token unless @order.user
      session[:order_id] = nil if @order.checkout.completed_at
      redirect_to order_url(@order, order_params) and next if params[:final_answer]
    end 

    success.wants.js do   
      @order.reload
      render :json => { :order_total => number_to_currency(@order.total),
                        :charges => charge_hash,  
                        :credits => credit_hash,
                        :available_methods => rate_hash}.to_json,
             :layout => false
    end
  end
  
  update.before do
    # update user to current one if user has logged in
    @order.update_attribute(:user, current_user) if current_user 

    if (checkout_info = params[:checkout]) and not checkout_info[:coupon_code]
      # overwrite any earlier guest checkout email if user has since logged in
      checkout_info[:email] = current_user.email if current_user 

      # and set the ip_address to the most recent one
      checkout_info[:ip_address] = request.env['REMOTE_ADDR']

      # check whether the bill address has changed, and start a fresh record if 
      # we were using the address stored in the current user.
      if checkout_info[:bill_address_attributes] and @checkout.bill_address
        # always include the id of the record we must write to - ajax can't refresh the form
        checkout_info[:bill_address_attributes][:id] = @checkout.bill_address.id
        new_address = Address.new checkout_info[:bill_address_attributes]
        if not @checkout.bill_address.same_as?(new_address) and
             current_user and @checkout.bill_address == current_user.bill_address
          # need to start a new record, so replace the existing one with a blank
          checkout_info[:bill_address_attributes].delete :id  
          @checkout.bill_address = Address.new
        end
      end

      # check whether the ship address has changed, and start a fresh record if 
      # we were using the address stored in the current user.
      if checkout_info[:shipment_attributes][:address_attributes] and @order.shipment.address
        # always include the id of the record we must write to - ajax can't refresh the form
        checkout_info[:shipment_attributes][:address_attributes][:id] = @order.shipment.address.id
        new_address = Address.new checkout_info[:shipment_attributes][:address_attributes]
        if not @order.shipment.address.same_as?(new_address) and 
             current_user and @order.shipment.address == current_user.ship_address 
          # need to start a new record, so replace the existing one with a blank
          checkout_info[:shipment_attributes][:address_attributes].delete :id
          @order.shipment.address = Address.new
        end
      end

    end
  end 
  
  update.after do
    @order.save!		# expect messages here
  end   
    
  private
  def object
    return @object if @object
    @object = parent_object.checkout                                                  
    unless params[:checkout] and params[:checkout][:coupon_code]
      # do not create these defaults if we're merely updating coupon code, otherwise we'll have a validation error
      if user = parent_object.user || current_user
        @object.shipment.address ||= user.ship_address 
        @object.bill_address     ||= user.bill_address
      end
      @object.shipment.address ||= Address.default
      @object.bill_address     ||= Address.default
      @object.creditcard       ||= Creditcard.new(:month => Date.today.month, :year => Date.today.year)
    end
    @object         
  end
  
  def load_data     
    @countries = Country.find(:all).sort  
    @shipping_countries = parent_object.shipping_countries.sort
    if current_user && current_user.bill_address
      default_country = current_user.bill_address.country 
    else
      default_country = Country.find Spree::Config[:default_country_id]	
    end 
    @states = default_country.states.sort
  end
  
  def rate_hash       
    fake_shipment = Shipment.new :order => @order, :address => @order.ship_address
    @order.shipping_methods.collect do |ship_method|
      fake_shipment.shipping_method = ship_method
      { :id   => ship_method.id, 
        :name => ship_method.name, 
        :rate => number_to_currency(ship_method.calculate_cost(fake_shipment)) }
    end
  end
  
  def charge_hash
    Hash[*@order.charges.collect { |c| [c.description, number_to_currency(c.amount)] }.flatten]    
  end           
  
  def credit_hash
    Hash[*@order.credits.collect { |c| [c.description, number_to_currency(c.amount)] }.flatten]    
  end
end
