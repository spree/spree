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
          # The lazyloaded associations here are pretty much attached to which nodes
          # we render on the view so we better update it any time a node is included
          # or removed from the views.
          base_scope = scope.includes(
            :option_values,
            :product,
            :default_price,
            :images,
            stock_items: :stock_location,
            option_values: :option_type
          )

          @variants = build_searcher(
            :Variant,
            scope: base_scope,
            q: params[:q],
            page: params[:page],
            per_page: params[:per_page]
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
          if params[:product_id]
            @product ||= Spree::Product.accessible_by(current_ability, :read).friendly.find(params[:product_id])
          end
        end

        def scope
          variants = @product.present? ? @product.variants_including_master : Variant

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
