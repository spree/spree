Spree::BaseController.class_eval do

  # graceful error handling for cancan authorization exceptions
  rescue_from CanCan::AccessDenied, :with => :access_denied

  # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
  # Override this method in your controllers if you want to have special behavior in case the user is not authorized
  # to access the requested action.  For example, a popup window might simply close itself.
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

  # Returns the currently authenticated user or the user associated with the guest_token stored in the session
  # when available.  This assists in providing authorization to guest users who may wish to create a new user
  # account at some point during the checkout (and thus, we cannot just log them in using the session token)
  def auth_user
    current_user || User.find_by_authentication_token(session[:guest_token])
  end

  # Overrides the default method used by Cancan so that we can use the guest_token in addition to current_user.
  def current_ability
    @current_ability ||= ::Ability.new(auth_user)
  end

end