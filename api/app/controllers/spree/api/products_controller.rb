module Spree
  module Api
    class ProductsController < Spree::Api::BaseController

      def index
        if params[:ids]
          @products = product_scope.where(:id => params[:ids].split(","))
        else
          @products = product_scope.ransack(params[:q]).result
        end

        @products = @products.page(params[:page]).per(params[:per_page])
      end

      def show
        @product = find_product(params[:id])
        expires_in 3.minutes
        respond_with(@product)
      end

      def new
      end

      def create
        authorize! :create, Product
        params[:product][:available_on] ||= Time.now
        begin
          @product = Product.new(product_params)
          if @product.save
            respond_with(@product, :status => 201, :default_template => :show)
          else
            invalid_resource!(@product)
          end
        rescue ActiveRecord::RecordNotUnique
          @product.permalink = nil
          retry
        end
      end

      def update
        @product = find_product(params[:id])
        authorize! :update, @product
        if @product.update_attributes(product_params)
          respond_with(@product, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        @product = find_product(params[:id])
        authorize! :destroy, @product
        @product.update_attribute(:deleted_at, Time.now)
        @product.variants_including_master.update_all(:deleted_at => Time.now)
        respond_with(@product, :status => 204)
      end

      private
        def product_params
          params.require(:product).permit(permitted_product_attributes)
        end
    end
  end
end
