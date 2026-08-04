module Spree
  module Core
    module ControllerHelpers
      module Auth
        extend ActiveSupport::Concern

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

        # Works out of the box for the default auth; override for custom auth systems.
        def store_location(location = nil)
          return if try_spree_current_user

          location ||= request.fullpath
          session_key = store_location_session_key

          session[session_key] = location
        end

        def store_location_session_key
          "#{Spree.customer_class.model_name.singular_route_key.to_sym}_return_to"
        end

        # proxy method to *possible* spree_current_user method
        # The host app (via authentication_helpers.rb) or an auth extension provides spree_current_user
        def try_spree_current_user
          # Provided by the host app, per authentication_helpers.rb
          if respond_to?(:spree_current_user)
            spree_current_user
          # Fallback name used by some auth integrations
          elsif respond_to?(:current_spree_user)
            current_spree_user
          end
        end
      end
    end
  end
end
