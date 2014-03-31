module Spree
  module Api
    class VariantsController < Spree::Api::BaseController

      before_filter :product

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
        @variants = scope.includes(:option_values).ransack(params[:q]).result.
          page(params[:page]).per(params[:per_page])
        respond_with(@variants)
      end

      def new
      end

      def show
        @variant = scope.includes(:option_values).find(params[:id])
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
