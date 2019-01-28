module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern
        include Spree::Core::TokenGenerator

        included do
          before_action :set_token
          helper_method :try_spree_current_user

          rescue_from CanCan::AccessDenied do |_exception|
            redirect_unauthorized_access
          end
        end

        # Needs to be overriden so that we use Spree's Ability rather than anyone else's.
        def current_ability
          @current_ability ||= Spree::Dependencies.ability_class.constantize.new(try_spree_current_user)
        end

        def redirect_back_or_default(default)
          redirect_to(session['spree_user_return_to'] || request.env['HTTP_REFERER'] || default)
          session['spree_user_return_to'] = nil
        end

        def set_token
          cookies.permanent.signed[:token] ||= cookies.signed[:guest_token]
          cookies.permanent.signed[:token] ||= {
            value: generate_token,
            httponly: true
          }
          cookies.permanent.signed[:guest_token] ||= cookies.permanent.signed[:token]
        end

        def current_oauth_token
          user = try_spree_current_user
          return unless user

          @current_oauth_token ||= Doorkeeper::AccessToken.active_for(user).last || Doorkeeper::AccessToken.create!(resource_owner_id: user.id)
        end

        def store_location
          # disallow return to login, logout, signup pages
          authentication_routes = [:spree_signup_path, :spree_login_path, :spree_logout_path]
          disallowed_urls = []
          authentication_routes.each do |route|
            disallowed_urls << send(route) if respond_to?(route)
          end

          disallowed_urls.map! { |url| url[/\/\w+$/] }
          unless disallowed_urls.include?(request.fullpath)
            session['spree_user_return_to'] = request.fullpath.gsub('//', '/')
          end
        end

        # proxy method to *possible* spree_current_user method
        # Authentication extensions (such as spree_auth_devise) are meant to provide spree_current_user
        def try_spree_current_user
          # This one will be defined by apps looking to hook into Spree
          # As per authentication_helpers.rb
          if respond_to?(:spree_current_user)
            spree_current_user
          # This one will be defined by Devise
          elsif respond_to?(:current_spree_user)
            current_spree_user
          end
        end

        # Redirect as appropriate when an access request fails.  The default action is to redirect to the login screen.
        # Override this method in your controllers if you want to have special behavior in case the user is not authorized
        # to access the requested action.  For example, a popup window might simply close itself.
        def redirect_unauthorized_access
          if try_spree_current_user
            flash[:error] = Spree.t(:authorization_failure)
            redirect_to spree.forbidden_path
          else
            store_location
            if respond_to?(:spree_login_path)
              redirect_to spree_login_path
            elsif spree.respond_to?(:root_path)
              redirect_to spree.root_path
            else
              redirect_to main_app.respond_to?(:root_path) ? main_app.root_path : '/'
            end
          end
        end
      end
    end
  end
end
