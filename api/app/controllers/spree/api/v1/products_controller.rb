module Spree
  module Api
    module V1
      class ProductsController < Spree::Api::V1::BaseController
        def index
          @products = scope.page(params[:page])
        end

        def show
          find_product
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
          find_product
          if @product.update_attributes(params[:product])
            render :show, :status => 200
          else
            invalid_resource!(@product)
          end
        end

        def destroy
          authorize! :delete, Product
          find_product
          @product.update_attribute(:deleted_at, Time.now)
          @product.variants_including_master.update_all(:deleted_at => Time.now)
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

        def find_product
          begin
            @product = scope.find_by_permalink!(params[:id])
          rescue ActiveRecord::RecordNotFound
            @product = scope.find(params[:id])
          end
        end
      end
    end
  end
end
