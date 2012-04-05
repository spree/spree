module Spree
  module Api
    module V1
      class ProductsController < Spree::Api::V1::BaseController
        def index
          @products = scope.page(params[:page])
        end

        def show
          find_product(params[:id])
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
          find_product(params[:id])
          if @product.update_attributes(params[:product])
            render :show, :status => 200
          else
            invalid_resource!(@product)
          end
        end

        def destroy
          authorize! :delete, Product
          find_product(params[:id])
          @product.update_attribute(:deleted_at, Time.now)
          @product.variants_including_master.update_all(:deleted_at => Time.now)
          render :text => nil, :status => 200
        end
      end
    end
  end
end
