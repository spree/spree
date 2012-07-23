module Spree
  module Api
    module V1
      class ProductsController < Spree::Api::V1::BaseController
        def index
          @products = product_scope.page(params[:page])
        end

        def search
          @products = product_scope.ransack(params[:q]).result.page(params[:page])
          render :index
        end

        def show
          @product = find_product(params[:id])
        end

        def new
        end

        def create
          authorize! :create, Product
          params[:product][:available_on] ||= Time.now
          @product = Product.new(params[:product])
          if @product.save
            render :show, :status => 201
          else
            invalid_resource!(@product)
          end
        end

        def update
          authorize! :update, Product
          @product = find_product(params[:id])
          if @product.update_attributes(params[:product])
            render :show, :status => 200
          else
            invalid_resource!(@product)
          end
        end

        def destroy
          authorize! :delete, Product
          @product = find_product(params[:id])
          @product.update_attribute(:deleted_at, Time.now)
          @product.variants_including_master.update_all(:deleted_at => Time.now)
          render :text => nil, :status => 200
        end
      end
    end
  end
end
