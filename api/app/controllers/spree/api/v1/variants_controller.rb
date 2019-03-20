module Spree
  module Api
    module V1
      class VariantsController < Spree::Api::BaseController
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

        # The lazyloaded associations here are pretty much attached to which nodes
        # we render on the view so we better update it any time a node is included
        # or removed from the views.
        def index
          @variants = scope.includes(*variant_includes).for_currency_and_available_price_amount.
                      ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@variants)
        end

        def new; end

        def show
          @variant = scope.includes(*variant_includes).find(params[:id])
          respond_with(@variant)
        end

        def update
          @variant = scope.accessible_by(current_ability, :update).find(params[:id])
          if @variant.update(variant_params)
            respond_with(@variant, status: 200, default_template: :show)
          else
            invalid_resource!(@product)
          end
        end

        private

        def product
          if params[:product_id]
            @product ||= Spree::Product.accessible_by(current_ability, :show).
                         friendly.find(params[:product_id])
          end
        end

        def scope
          variants = if @product
                       @product.variants_including_master
                     else
                       Variant
                     end

          if current_ability.can?(:manage, Variant) && params[:show_deleted]
            variants = variants.with_deleted
          end

          variants.eligible.accessible_by(current_ability)
        end

        def variant_params
          params.require(:variant).permit(permitted_variant_attributes)
        end

        def variant_includes
          [{ option_values: :option_type }, :product, :default_price, :images, { stock_items: :stock_location }]
        end
      end
    end
  end
end
