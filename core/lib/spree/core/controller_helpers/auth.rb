module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern
        include Spree::Core::TokenGenerator

        included do
          if defined?(helper_method)
            helper_method :try_spree_current_user
          end

          rescue_from CanCan::AccessDenied do |_exception|
            redirect_unauthorized_access
          end
        end

        # Needs to be overridden so that we use Spree's Ability rather than anyone else's.
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
          get_last_access_token = ->(user) { Spree::OauthAccessToken.active_for(user).where(expires_in: nil).last }
          create_access_token = ->(user) { Spree::OauthAccessToken.create!(resource_owner: user) }
          user = try_spree_current_user
          return unless user

          @current_oauth_token ||= get_last_access_token.call(user) || create_access_token.call(user)
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
      end
    end
  end
end
