module Spree
  module Api
    module V1
      class VariantsController < Spree::Api::BaseController
        include Spree::Core::ControllerHelpers::Search

        before_action :product

        def create
          authorize! :create, Variant
          @variant = scope.new(variant_params)
          if @variant.save
            respond_with(@variant, status: 201, default_template: :show)
          else
            invalid_resource!(@variant)
          end
        end

        def destroy
          @variant = scope.accessible_by(current_ability, :destroy).find(params[:id])
          @variant.destroy
          respond_with(@variant, status: 204)
        end

        def index
          @variants = build_searcher(
            :Variant, {
              scope:    scope,
              q:        params[:q],
              page:     params[:page],
              per_page: params[:per_page]
            }
          ).search

          respond_with(@variants)
        end

        def new
        end

        def show
          @variant = scope.includes({ option_values: :option_type }, :option_values, :product, :default_price, :images, { stock_items: :stock_location })
            .find(params[:id])
          respond_with(@variant)
        end

        def update
          @variant = scope.accessible_by(current_ability, :update).find(params[:id])
          if @variant.update_attributes(variant_params)
            respond_with(@variant, status: 200, default_template: :show)
          else
            invalid_resource!(@product)
          end
        end

        private
          def product
            @product ||= Spree::Product.accessible_by(current_ability, :read).friendly.find(params[:product_id]) if params[:product_id]
          end

          def scope
            if @product
              variants = @product.variants_including_master
            else
              variants = Variant
            end

            if current_ability.can?(:manage, Variant) && params[:show_deleted]
              variants = variants.with_deleted
            end

            variants.accessible_by(current_ability, :read)
          end

          def variant_params
            params.require(:variant).permit(permitted_variant_attributes)
          end
      end
    end
  end
end
