Spree::BaseController.class_eval do

  include Spree::AuthUser

  # graceful error handling for cancan authorization exceptions
  rescue_from CanCan::AccessDenied, :with => :unauthorized

  private


  def current_user_session
    return @current_user_session if defined?(@current_user_session)
    @current_user_session = UserSession.find
  end

  def current_user
    return @current_user if defined?(@current_user)
    @current_user = current_user_session && current_user_session.user
  end

  helper_method :current_user_session, :current_user




  # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
  # Override this method in your controllers if you want to have special behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might simply close itself.
  def unauthorized
    respond_to do |format|
      format.html do
        if current_user
          flash.now[:error] = I18n.t(:authorization_failure)
          render 'shared/unauthorized', :layout => 'spree_application'
        else
          store_location
          redirect_to login_path and return
        end
      end
      format.xml do
        request_http_basic_authentication 'Web Password'
      end
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

end
