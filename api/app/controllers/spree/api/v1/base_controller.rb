module Spree
  module Api
    module V1
      class BaseController < ActionController::Metal
        include ActionController::ImplicitRender
        include ActionController::Rendering
        include AbstractController::ViewPaths
        append_view_path "app/views"
      end
    end
  end
end

