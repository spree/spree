module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include ActionController::ImplicitRender
        include ActionController::Rendering
        include AbstractController::ViewPaths
        include AbstractController::Callbacks
        append_view_path "app/views"

        before_filter :check_for_api_key
        before_filter :authenticate_user

        private

        def check_for_api_key
          # TODO: Work out why we can't use straight render :json here.
          render "spree/api/v1/errors/must_specify_api_key" and return if params[:key].blank?
        end

        def authenticate_user
          unless User.authenticate_for_api(params[:key])
            render "spree/api/v1/errors/invalid_api_key" and return
          end
        end
      end
    end
  end
end

