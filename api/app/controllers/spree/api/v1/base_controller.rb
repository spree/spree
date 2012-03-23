module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include Spree::Api::ControllerSetup

        attr_accessor :current_user

        before_filter :check_for_api_key
        before_filter :authenticate_user

        rescue_from CanCan::AccessDenied, :with => :unauthorized

        private

        def check_for_api_key
          # TODO: Work out why we can't use straight render :json here.
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

        def current_ability
          Spree::Ability.new(current_user)
        end
      end
    end
  end
end

