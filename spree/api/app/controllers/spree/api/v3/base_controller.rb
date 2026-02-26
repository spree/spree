module Spree
  module Api
    module V3
      class BaseController < ActionController::API
        include ActiveStorage::SetCurrent
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Api::V3::LocaleAndCurrency
        include Spree::Api::V3::JwtAuthentication
        include Spree::Api::V3::ApiKeyAuthentication
        include Spree::Api::V3::ErrorHandler
        include Spree::Api::V3::HttpCaching
        include Spree::Api::V3::SecurityHeaders
        include Spree::Api::V3::ResourceSerializer
        include Pagy::Method

        # Optional JWT authentication by default
        before_action :authenticate_user

        protected

        # Override to use current_user from JWT authentication
        # @return [Spree.user_class]
        def spree_current_user
          current_user
        end

        alias try_spree_current_user spree_current_user

        # CanCanCan ability
        # @return [Spree::Ability]
        def current_ability
          @current_ability ||= Spree::Ability.new(current_user, ability_options)
        end

        # Options passed to the CanCanCan ability
        # @return [Hash]
        def ability_options
          { store: current_store }
        end
      end
    end
  end
end
