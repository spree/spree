module Spree
  module Api
    module V1
      class ProductsController < Spree::Api::V1::BaseController
        def index
          @products = scope.page(params[:page])
        end

        def show
          @product = scope.find_by_permalink!(params[:id])
        end

        def new
        end

        def create
          authorize! :create, Product
          @product = Product.new(params[:product])
          if @product.save
            render :show, :status => 201
          else
            invalid_resource!(@product)
          end
        end

        def update
          authorize! :update, Product
          @product = Product.find_by_permalink!(params[:id])
          if @product.update_attributes(params[:product])
            render :show, :status => 200
          else
            invalid_resource!(@product)
          end
        end

        def destroy
          authorize! :delete, Product
          @product = Product.find_by_permalink!(params[:id])
          @product.destroy
          render :text => nil, :status => 200
        end

        private
        def scope
          if current_api_user.has_role?("admin")
            scope = Product
          else
            scope = Product.active
          end
          scope.includes(:master)
        end
      end
    end
  end
end
