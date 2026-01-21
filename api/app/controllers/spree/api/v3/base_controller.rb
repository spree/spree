module Spree
  module Api
    module V3
      class BaseController < ActionController::API
        include ActiveStorage::SetCurrent
        include CanCan::ControllerAdditions
        include Spree::Core::ControllerHelpers::StrongParameters
        include Spree::Core::ControllerHelpers::Store
        include Spree::Core::ControllerHelpers::Locale
        include Spree::Core::ControllerHelpers::Currency
        include Spree::Api::V3::Authentication
        include Spree::Api::V3::ErrorHandler
        include Spree::Api::V3::HttpCaching
        include Spree::Api::V3::ResourceSerializer
        include Pagy::Method

        # Optional authentication by default
        before_action :authenticate_user

        protected

        # Override to use current_user from JWT authentication
        def spree_current_user
          current_user
        end

        alias try_spree_current_user spree_current_user

        # CanCanCan ability
        def current_ability
          @current_ability ||= Spree::Ability.new(current_user, ability_options)
        end

        def ability_options
          { store: current_store }
        end
      end
    end
  end
end
