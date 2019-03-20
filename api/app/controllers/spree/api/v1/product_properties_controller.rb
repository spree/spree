module Spree
  module Api
    module V1
      class ProductPropertiesController < Spree::Api::BaseController
        before_action :find_product, :authorize_product!
        before_action :product_property, only: [:show, :update, :destroy]

        def index
          @product_properties = @product.product_properties.accessible_by(current_ability).
                                ransack(params[:q]).result.
                                page(params[:page]).per(params[:per_page])
          respond_with(@product_properties)
        end

        def show
          respond_with(@product_property)
        end

        def new; end

        def create
          authorize! :create, ProductProperty
          @product_property = @product.product_properties.new(product_property_params)
          if @product_property.save
            respond_with(@product_property, status: 201, default_template: :show)
          else
            invalid_resource!(@product_property)
          end
        end

        def update
          authorize! :update, @product_property

          if @product_property.update(product_property_params)
            respond_with(@product_property, status: 200, default_template: :show)
          else
            invalid_resource!(@product_property)
          end
        end

        def destroy
          authorize! :destroy, @product_property
          @product_property.destroy
          respond_with(@product_property, status: 204)
        end

        private

        def find_product
          super(params[:product_id])
        end

        def authorize_product!
          authorize! :show, @product
        end

        def product_property
          if @product
            @product_property ||= @product.product_properties.find_by(id: params[:id])
            @product_property ||= @product.product_properties.includes(:property).where(spree_properties: { name: params[:id] }).first
            raise ActiveRecord::RecordNotFound unless @product_property

            authorize! :show, @product_property
          end
        end

        def product_property_params
          params.require(:product_property).permit(permitted_product_properties_attributes)
        end
      end
    end
  end
end
