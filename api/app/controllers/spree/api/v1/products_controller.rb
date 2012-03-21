require 'abstract_controller'
require 'action_controller/metal'
require 'action_controller/metal/implicit_render'
require 'action_controller/metal/rendering'
module Spree
  module Api
    module V1
      class ProductsController < ActionController::Metal
        include ActionController::ImplicitRender
        include ActionController::Rendering
        append_view_path "app/views"

        def index
          @products = Product.page(params[:page])
        end

        def show
          @product = Product.find_by_permalink!(params[:id])
        end
      end
    end
  end
end
