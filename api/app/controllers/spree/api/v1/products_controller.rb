module Spree
  module Api
    module V1
      class ProductsController < BaseController
        def index
          @products = Product.page(params[:page])
        end

        def show
          @product = Product.find_by_permalink!(params[:id])
        end

        def create
          authorize! :create, Product
          render :json => { :status => "OK" }
        end
      end
    end
  end
end
