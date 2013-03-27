require 'spree/core/ssl_requirement'

module Spree
  module Core
    module ControllerHelpers
      module Auth
        def self.included(base)
          base.class_eval do
            include SslRequirement

            helper_method :try_spree_current_user

            rescue_from CanCan::AccessDenied do |exception|
              return unauthorized
            end
          end
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Ability.new(try_spree_current_user)
        end

        # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
        # Override this method in your controllers if you want to have special behavior in case the user is not authorized
        # to access the requested action.  For example, a popup window might simply close itself.
        def unauthorized
          if try_spree_current_user
            flash[:error] = t(:authorization_failure)
            redirect_to '/unauthorized'
          else
            store_location
            url = spree.respond_to?(:spree_login_path) ? spree.spree_login_path : spree.root_path
            redirect_to url
          end
        end

        def store_location
          # disallow return to login, logout, signup pages
          authentication_routes = [:spree_signup_path, :spree_login_path, :spree_logout_path]
          disallowed_urls = []
          authentication_routes.each do |route|
            if respond_to?(route)
              disallowed_urls << send(route)
            end
          end

          disallowed_urls.map!{ |url| url[/\/\w+$/] }
          unless disallowed_urls.include?(request.fullpath)
            session['user_return_to'] = request.fullpath.gsub('//', '/')
          end
        end

        # proxy method to *possible* spree_current_user method
        # Authentication extensions (such as spree_auth_devise) are meant to provide spree_current_user
        def try_spree_current_user
          respond_to?(:spree_current_user) ? spree_current_user : nil
        end

        def redirect_back_or_default(default)
          redirect_to(session["user_return_to"] || default)
          session["user_return_to"] = nil
        end
      end
    end
  end
end
