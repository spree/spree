module Spree
  module Api
    class ProductPropertiesController < Spree::Api::BaseController
      respond_to :json

      before_filter :find_product
      before_filter :product_property, :only => [:show, :update, :destroy]

      def index
        @product_properties = @product.product_properties.ransack(params[:q]).result
          .page(params[:page]).per(params[:per_page])
        respond_with(@product_properties)
      end

      def show
        respond_with(@product_property)
      end

      def new
      end

      def create
        authorize! :create, ProductProperty
        @product_property = @product.product_properties.new(params[:product_property])
        if @product_property.save
          respond_with(@product_property, :status => 201, :default_template => :show)
        else
          invalid_resource!(@product_property)
        end
      end

      def update
        authorize! :update, ProductProperty
        if @product_property  && @product_property.update_attributes(params[:product_property])
          respond_with(@product_property, :status => 200, :default_template => :show)
        else
          invalid_resource!(@product_property)
        end
      end

      def destroy
        authorize! :delete, ProductProperty
        if(@product_property)
          @product_property.destroy
          respond_with(@product_property, :status => 204)
        else
          invalid_resource!(@product_property)
        end

      end

      private
        def find_product
          @product = super(params[:product_id])
        end

        def product_property
          if @product
            @product_property ||= @product.product_properties.find_by_id(params[:id])
            @product_property ||= @product.product_properties.joins(:property).where('spree_properties.name' => params[:id]).readonly(false).first
          end
        end
    end
  end
end
