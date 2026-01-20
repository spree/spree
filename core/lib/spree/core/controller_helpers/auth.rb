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
          @current_ability ||= Spree.ability_class.new(try_spree_current_user, { store: current_store })
        end

        def current_oauth_token
          get_last_access_token = ->(user) { Spree::OauthAccessToken.active_for(user).where(expires_in: nil).last }
          create_access_token = ->(user) { Spree::OauthAccessToken.create!(resource_owner: user) }
          user = try_spree_current_user
          return unless user

          @current_oauth_token ||= get_last_access_token.call(user) || create_access_token.call(user)
        end

        # this will work for devise out of the box
        # for other auth systems you will need to override this method
        def store_location(location = nil)
          return if try_spree_current_user

          location ||= request.fullpath
          session_key = store_location_session_key

          session[session_key] = location
        end

        def store_location_session_key
          "#{Spree.user_class.model_name.singular_route_key.to_sym}_return_to"
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
