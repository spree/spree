class Spree::BaseController < ApplicationController

  filter_parameter_logging :password, :number, :verification_value
  helper_method :title, :set_title

  # retrieve the order_id from the session and then load from the database (or return a new order if no 
  # such id exists in the session)
  def find_order      
    unless session[:order_id].blank?
      @order = Order.find_or_create_by_id(session[:order_id])
    else      
      @order = Order.create
    end
    session[:order_id]    = @order.id
    session[:order_token] = @order.token
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

  # set_title can be used in views as well as controllers.
  # e.g. <% set_title 'This is a custom title for this view' %>
  def set_title(title)
    @title = title
  end
  
  def title
    if @title.blank?
      default_title
    else
      @title
    end
  end
  
  def default_title
    Spree::Config[:site_name]
  end
  
end
