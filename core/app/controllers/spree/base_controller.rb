require 'cancan'

class Spree::BaseController < ApplicationController
  include Spree::Core::ControllerHelpers
  include Spree::Core::RespondWith

  # graceful error handling for cancan authorization exceptions
  rescue_from CanCan::AccessDenied do |exception|
    return unauthorized
  end

  private

    def current_spree_user
      if Spree.user_class && Spree.current_user_method
        send(Spree.current_user_method)
      else
        nil
      end
    end

    # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
    def current_ability
      @current_ability ||= Spree::Ability.new(current_spree_user)
    end
    # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
    # Override this method in your controllers if you want to have special behavior in case the user is not authorized
    # to access the requested action.  For example, a popup window might simply close itself.
    def unauthorized
      respond_to do |format|
        format.html do
          if current_spree_user
            flash.now[:error] = t(:authorization_failure)
            render 'spree/shared/unauthorized', :layout => '/spree/layouts/spree_application', :status => 401
          else
            store_location
            redirect_to spree_login_path and return
          end
        end
        format.xml do
          request_http_basic_authentication 'Web Password'
        end
        format.json do
          render :text => "Not Authorized \n", :status => 401
        end
      end
    end

    def spree_login_path
      spree.login_path
    end
end
