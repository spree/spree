module Spree
  module Api
    module V1
      class ProductPropertiesController < Spree::Api::V1::BaseController
        before_filter :find_product
        before_filter :product_property, :only => [:show, :update, :destroy]

        def index
          @product_properties = @product.product_properties.
                                ransack(params[:q]).result.
                                page(params[:page]).per(params[:per_page])
        end

        def show
        end

        def new
        end

        def create
          authorize! :create, ProductProperty
          @product_property = @product.product_properties.new(params[:product_property])
          if @product_property.save
            render :show, :status => 201
          else
            invalid_resource!(@product_property)
          end
        end

        def update
          authorize! :update, ProductProperty
          if @product_property  && @product_property.update_attributes(params[:product_property])
            render :show, :status => 200
          else
            invalid_resource!(@product_property)
          end
        end

        def destroy
          authorize! :delete, ProductProperty
          if(@product_property)
            @product_property.destroy
            render :text => nil, :status => 204
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
end
