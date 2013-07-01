module Spree
  module Api
    class ProductsController < Spree::Api::BaseController
      respond_to :json

      def index
        if params[:ids]
          @products = product_scope.where(:id => params[:ids])
        else
          @products = product_scope.ransack(params[:q]).result
        end

        @products = @products.page(params[:page]).per(params[:per_page])

        respond_with(@products)
      end

      def show
        @product = find_product(params[:id])
        respond_with(@product)
      end

      def new
      end

      def create
        authorize! :create, Product
        params[:product][:available_on] ||= Time.now
        @product = Product.new(params[:product])
        begin
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
        authorize! :update, Product
        @product = find_product(params[:id])
        if @product.update_attributes(params[:product])
          respond_with(@product, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product)
        end
      end

      def destroy
        authorize! :delete, Product
        @product = find_product(params[:id])
        @product.update_attribute(:deleted_at, Time.now)
        @product.variants_including_master.update_all(:deleted_at => Time.now)
        respond_with(@product, :status => 204)
      end
    end
  end
end
