class Spree::BaseController < ActionController::Base
  layout 'spree_application'
  helper :application, :hook
  before_filter :instantiate_controller_and_action_names
  before_filter :touch_sti_subclasses
  filter_parameter_logging :password, :password_confirmation, :number, :verification_value
  helper_method :current_user_session, :current_user, :title, :title=, :get_taxonomies, :current_gateway

  # Pick a unique cookie name to distinguish our session data from others'
  session_options['session_key'] = '_spree_session_id'
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  include RoleRequirementSystem
  include EasyRoleRequirementSystem
  include SslRequirement

  def admin_created?
    User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])
  end

  # retrieve the order_id from the session and then load from the database (or return a new order if no
  # such id exists in the session)
  def find_order
    if !session[:order_id].blank?
      @order = Order.find_or_create_by_id(session[:order_id])
    elsif request.get?
      @order = Order.new(:user => current_user)
    else
      @order = Order.create(:user => current_user)
    end
    session[:order_id]    = @order.id
    session[:order_token] = @order.token
    @order
  end

  def access_forbidden
    render :text => 'Access Forbidden', :layout => true, :status => 401
  end

  # can be used in views as well as controllers.
  # e.g. <% title = 'This is a custom title for this view' %>
  def title=(title)
    @title = title
  end

  def title
    title_string = @title.blank? ? accurate_title : @title
    if title_string.blank?
      default_title
    else
      if Spree::Config[:always_put_site_name_in_title]
        [default_title, title_string].join(' - ')
      else
        title_string
      end
    end
  end

  protected

  def default_title
    Spree::Config[:site_name]
  end
  
  def accurate_title
    return nil
  end
  
  def reject_unknown_object
    # workaround to catch problems with loading errors for permalink ids (reconsider RC permalink hack elsewhere?)
    begin
      load_object
    rescue Exception => e
      @object = nil
    end
    the_object = instance_variable_get "@#{object_name}"
    the_object = nil if (the_object.respond_to?(:deleted?) && the_object.deleted?)
    unless params[:id].blank? || the_object
      if self.respond_to? :object_missing
        self.object_missing(params[:id])
      else
        render_404(Exception.new("missing object in #{self.class.to_s}"))
      end
    end
    true
  end

  def render_404(exception)
    respond_to do |type|
      type.html { render :file    => "#{RAILS_ROOT}/public/404.html", :status => "404 Not Found" }
      type.all  { render :nothing => true,                            :status => "404 Not Found" }
    end
  end

  private
  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  def require_user
    unless current_user
      store_location
      flash[:notice] = I18n.t("page_only_viewable_when_logged_in")
      redirect_to new_user_session_url
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = I18n.t("page_only_viewable_when_logged_out")
      redirect_to root_url
      return false
    end
  end

  def store_location
    # disallow return to login, logout, signup pages
    disallowed_urls = [signup_url, login_url, logout_url]
    disallowed_urls.map!{|url| url[/\/\w+$/]}
    unless disallowed_urls.include?(request.request_uri)
      session[:return_to] = request.request_uri
    end
  end

  def redirect_back_or_default(default)
    redirect_to(session[:return_to] || default)
    session[:return_to] = nil
  end

  # Redirect as appropriate when an access request fails.
  #
  # The default action is to redirect to the login screen.
  #
  # Override this method in your controllers if you want to have special
  # behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might
  # simply close itself.
  def access_denied
    respond_to do |format|
      format.html do
        if current_user
          flash[:error] = t("authorization_failure")
          redirect_to '/user_sessions/authorization_failure'
          next
        else
          store_location
          redirect_to login_path
          next
        end
      end
      format.xml do
        request_http_basic_authentication 'Web Password'
      end
    end
  end

  def instantiate_controller_and_action_names
    @current_action = action_name
    @current_controller = controller_name
  end

  def get_taxonomies
    @taxonomies ||= Taxonomy.find(:all, :include => {:root => :children})
    @taxonomies
  end

  def current_gateway
    @current_gateway ||= Gateway.current
  end

  # Load all models using STI to fix associations such as @order.credits giving no results and resulting in incorrect order totals
  def touch_sti_subclasses
    if RAILS_ENV == 'development'
      load(File.join(SPREE_ROOT,'config/initializers/touch.rb'))
    end
  end

end
