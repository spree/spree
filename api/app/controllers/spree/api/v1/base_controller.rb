module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include ActionController::ImplicitRender
        include ActionController::Rendering
        include AbstractController::ViewPaths
        include AbstractController::Callbacks
        append_view_path "app/views"

        before_filter :authenticate_user

        private

        def authenticate_user
          # TODO: Work out why we can't use straight render :json here.
          render "spree/api/v1/errors/must_specify_api_key" if params[:key].blank?
        end

      end
    end
  end
end

