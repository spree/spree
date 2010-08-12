Spree::BaseController.class_eval do
  # graceful error handling for cancan authorization exceptions
  rescue_from CanCan::AccessDenied, :with => :access_denied

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
end