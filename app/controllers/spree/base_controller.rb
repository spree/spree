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
 
  protected
  def reject_unknown_object
    # workaround to catch problems with loading errors for permalink ids (reconsider RC hack elsewhere?)
    begin 
      load_object
    rescue Exception => e
      @object = nil
    end
    the_object = instance_variable_get "@#{object_name}"
    if params[:id] && the_object.nil? 
      if self.respond_to? :object_missing
        self.object_missing(params[:id])
      else 
        render_404(Exception.new "missing object in #{self.class.to_s}")
      end
    end
  end         
  
  def render_404(exception)
    respond_to do |type|
      type.html { render :file    => "#{RAILS_ROOT}/public/404.html", :status => "404 Not Found" }
      type.all  { render :nothing => true,                            :status => "404 Not Found" }
    end
  end
end
