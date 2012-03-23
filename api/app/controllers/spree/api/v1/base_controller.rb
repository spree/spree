module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include Spree::Api::ControllerSetup

        attr_accessor :current_user

        before_filter :check_for_api_key
        before_filter :authenticate_user

        rescue_from CanCan::AccessDenied, :with => :unauthorized
        rescue_from ActiveRecord::RecordNotFound, :with => :not_found

        helper Spree::Api::ApiHelpers

        private

        def check_for_api_key
          render "spree/api/v1/errors/must_specify_api_key" and return if params[:key].blank?
        end

        def authenticate_user
          unless @current_user = User.find_by_api_key(params[:key])
            render "spree/api/v1/errors/invalid_api_key" and return
          end
        end

        def unauthorized
          render "spree/api/v1/errors/unauthorized", :status => 401 and return
        end

        def not_found
          render "spree/api/v1/errors/not_found", :status => 404 and return
        end

        def current_ability
          Spree::Ability.new(current_user)
        end

        def invalid_resource!(resource)
          render "spree/api/v1/errors/invalid_resource", :resource => resource, :status => 422
        end
      end
    end
  end
end

