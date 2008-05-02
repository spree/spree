class Spree::BaseController < ApplicationController
  
  CalendarDateSelect.format = :american
  #model :order, :address
  
  filter_parameter_logging "password"
  
  def find_cart
    id = session[:cart_id]    
    unless id.blank?
      @cart = Cart.find_or_create_by_id(id)
    else
      @cart = Cart.create
      session[:cart_id] = @cart.id
    end
  end

  def access_denied
    if logged_in?
      access_forbidden
    else
      store_location
      redirect_to :controller => '/account', :action => 'login'
    end
    false  
  end

  def access_forbidden
    render :text => 'Access Forbidden', :layout => true, :status => 401
  end
  
  # Instantiates the selected PAYMENT_GATEWAY and initializes with GATEWAY_OPTIONS (configured in environment.rb)
  def payment_gateway
    ActiveMerchant::Billing::Base.gateway_mode = :test unless RAILS_ENV == "production"
    PAYMENT_GATEWAY.constantize.new(GATEWAY_OPTIONS)
  end
end