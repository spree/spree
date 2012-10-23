module Spree
  module Api
    module V1
      class VariantsController < Spree::Api::V1::BaseController
        before_filter :product

        def index
          @variants = scope.includes(:option_values).page(params[:page])
        end

        def show
          @variant = scope.includes(:option_values).find(params[:id])
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
            if @product
              unless current_api_user.has_spree_role?("admin") || params[:show_deleted]
                variants = @product.variants_including_master
              else
                variants = @product.variants_including_master_and_deleted
              end
            else
              variants = Variant.scoped
              if current_api_user.has_spree_role?("admin")
                unless params[:show_deleted]
                  variants = Variant.active
                end
              else
                variants = variants.active
              end
            end
            variants
          end
      end
    end
  end
end
