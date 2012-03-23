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
            invalid_resource!
          end
        end

        def update
          authorize! :update, Product
          @product = Product.find_by_permalink!(params[:id])
          if @product.update_attributes(params[:product])
            render :show, :status => 200
          else
            invalid_resource!
          end
        end

        def destroy
          authorize! :delete, Product
          @product = Product.find_by_permalink!(params[:id])
          @product.destroy
          render :text => nil, :status => 200
        end
      end
    end
  end
end
