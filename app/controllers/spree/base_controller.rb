class Spree::BaseController < ApplicationController

  filter_parameter_logging :password, :number, :verification_value

  # retrieve the order_id from the session and then load from the database (or return a new order if no 
  # such id exists in the session)
  def find_order      
    unless session[:order_id].blank?
      @order = Order.find_or_create_by_id(session[:order_id])
    else      
      @order = Order.create
    end
    session[:order_id] = @order.id
    @order
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