module Spree
  module Api
    class ProductPropertiesController < Spree::Api::BaseController

      before_action :find_product
      before_action :product_property, only: [:show, :update, :destroy]

      def index
        @product_properties = @product.product_properties.accessible_by(current_ability, :read).
                              ransack(params[:q]).result.
                              page(params[:page]).per(params[:per_page])
        respond_with(@product_properties)
      end

      def show
        respond_with(@product_property)
      end

      def new
      end

      def create
        authorize! :create, Spree::ProductProperty
        @product_property = @product.product_properties.new(product_property_params)
        if @product_property.save
          respond_with(@product_property, status: 201, default_template: :show)
        else
          invalid_resource!(@product_property)
        end
      end

      def update
        if @product_property
          authorize! :update, @product_property
          @product_property.update_attributes(product_property_params)
          respond_with(@product_property, status: 200, default_template: :show)
        else
          invalid_resource!(@product_property)
        end
      end

      def destroy
        if @product_property
          authorize! :destroy, @product_property
          @product_property.destroy
          respond_with(@product_property, status: 204)
        else
          invalid_resource!(@product_property)
        end
      end

      private

        def find_product
          @product = super(params[:product_id])
          authorize! :read, @product
        end

        def product_property
          if @product
            @product_property ||= @product.product_properties.find_by(id: params[:id])
            @product_property ||= @product.product_properties.includes(:property).where(spree_properties: { name: params[:id] }).first
            authorize! :read, @product_property
          end
        end

        def product_property_params
          params.require(:product_property).permit(permitted_product_properties_attributes)
        end
    end
  end
end
