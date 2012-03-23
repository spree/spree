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

        def new
        end

        def create
          authorize! :create, Product
          @product = Product.new(params[:product])
          if @product.save
            render :show, :status => 201
          else
            render "spree/api/v1/errors/invalid_resource", :resource => @product, :status => 422
          end
        end
      end
    end
  end
end
