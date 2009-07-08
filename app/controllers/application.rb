# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  before_filter :instantiate_controller_and_action_names
  filter_parameter_logging :password, :password_confirmation
  helper_method :current_user_session, :current_user

  # Pick a unique cookie name to distinguish our session data from others'
  session_options['session_key'] = '_spree_session_id'

  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  #include AuthenticatedSystem
  include RoleRequirementSystem
  include EasyRoleRequirementSystem
  include SslRequirement
  
  def admin_created?
    User.first(:include => :roles, :conditions => ["roles.name = 'admin'"])
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
      flash[:notice] = "You must be logged in to access this page"
      redirect_to new_user_session_url
      return false
    end
  end

  def require_no_user
    if current_user
      store_location
      flash[:notice] = "You must be logged out to access this page"
      redirect_to account_url
      return false
    end
  end

  def store_location
    session[:return_to] = request.request_uri
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
  
    @taxonomies = Taxonomy.find(:all, :include => {:root => :children})
  end
end
