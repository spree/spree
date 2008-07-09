class Spree::BaseController < ApplicationController
  
  CalendarDateSelect.format = :american
  
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

  def access_forbidden
    render :text => 'Access Forbidden', :layout => true, :status => 401
  end
  
  # Used for pages which need to render certain partials in the middle
  # of a view. Ex. Extra user form fields
  def initialize_extension_partials
    @extension_partials = []
  end
  
end