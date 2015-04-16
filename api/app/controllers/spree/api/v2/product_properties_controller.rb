module Spree
  module Api
    module V2
      class ProductPropertiesController < Spree::Api::BaseController

        before_action :find_product
        before_action :product_property, only: [:show, :update, :destroy]

        def index
          @product_properties = @product.product_properties.accessible_by(current_ability, :read).
                                ransack(params[:q]).result.
                                page(params[:page]).per(params[:per_page])
          render json: @product_properties, meta: pagination(@product_properties)
        end

        def show
          render json: @product_property
        end

        def new
        end

        def create
          authorize! :create, ProductProperty
          @product_property = @product.product_properties.new(product_property_params)
          if @product_property.save
            render json: @product_property, status: 201
          else
            invalid_resource!(@product_property)
          end
        end

        def update
          if @product_property
            authorize! :update, @product_property
            @product_property.update_attributes(product_property_params)
            render json: @product_property, status: 200
          else
            invalid_resource!(@product_property)
          end
        end

        def destroy
          if @product_property
            authorize! :destroy, @product_property
            @product_property.destroy
            render json: @product_property, status: 204
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
end
