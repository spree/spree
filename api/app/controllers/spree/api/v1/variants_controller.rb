module Spree
  module Api
    module V1
      class VariantsController < BaseController
        before_filter :product

        def index
          @variants = scope.scoped
        end

        def show
          @variant = scope.find(params[:id])
        end

        def new
        end

        def create
          authorize! :create, Variant
          @variant = scope.new(params[:product])
          if @variant.save
            render :show, :status => 201
          else
            invalid_resource!(@variant)
          end
        end

        def update
          authorize! :update, Variant
          @variant = scope.find(params[:id])
          if @variant.update_attributes(params[:variant])
            render :show, :status => 200
          else
            invalid_resource!(@product)
          end
        end

        def destroy
          authorize! :delete, Variant
          @variant = scope.find(params[:id])
          @variant.destroy
          render :text => nil, :status => 200
        end

        private
          def product
            @product ||= Spree::Product.find_by_permalink(params[:product_id]) if params[:product_id]
          end

          def scope
            @product ? @product.variants : Variant
          end
      end
    end
  end
end
