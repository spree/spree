module Spree
  module Admin
    class VariantsController < ResourceController
      include StockLocationsHelper

      include ProductsBreadcrumbConcern

      belongs_to 'spree/product', find_by: :slug
      before_action :load_data, only: [:edit, :update]
      before_action :strip_attributes, only: [:update]
      before_action :add_breadcrumbs

      edit_action.before :build_prices
      edit_action.before :build_stock_items

      def search
        query = params[:q]&.strip

        if query.blank? || query.length < 3
          respond_to do |format|
            format.turbo_stream { head :ok }
            format.json { render json: [] }
          end
        else
          access_action = request.post? ? :manage : :index

          scope = current_store.variants.accessible_by(current_ability, access_action)
          unless params[:all].to_b.present?
            scope = if params[:currency].present?
                      scope.active(params[:currency]).merge(current_store.products.published)
                    else
                      scope.active.merge(current_store.products.published)
                    end
          end
          scope = scope.where.not(id: params[:omit_ids].split(',')) if params[:omit_ids].present?
          scope = scope.where(spree_stock_items: { stock_location_id: params[:stock_location_id] }) if params[:stock_location_id].present?

          @variants = scope.
                      eligible.
                      multi_search(query).
                      includes(:images, :prices, :stock_items, :stock_locations, :product, option_values: :option_type).
                      limit(params[:limit] || 20).
                      reorder('').
                      distinct(false)

          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: [
                turbo_stream.replace(
                  "variants_search_results",
                  partial: "spree/admin/variants/search_results",
                  locals: { variants: @variants }
                )
              ]
            end

            format.json do
              # we cannot use pluck here, as `descriptive_name` is not a column
              render json: @variants.map { |v| { id: v.id, name: v.descriptive_name } }
            end
          end
        end
      end

      private

      def load_data
        @tax_categories = TaxCategory.order(:name)
      end

      def location_after_destroy
        spree.edit_admin_product_path(@product)
      end

      def build_prices
        current_store.supported_currencies_list.each do |currency|
          @variant.prices.build(currency: currency) unless @variant.prices.exists?(currency: currency.iso_code)
        end
      end

      def build_stock_items
        available_stock_locations.each do |stock_location|
          @variant.stock_items.build(stock_location: stock_location) unless @variant.stock_items.exists?(stock_location: stock_location)
        end
      end

      def strip_attributes
        params[:variant].delete(:prices_attributes) unless can?(:manage, @variant.prices.first)
        params[:variant].delete(:stock_items_attributes) unless can?(:manage, @variant.stock_items.first)
      end

      def add_breadcrumbs
        if @variant.present? && @variant.persisted?
          add_breadcrumb @variant.human_name, spree.edit_admin_product_variant_path(@product, @variant)
        end
      end

      def permitted_resource_params
        params.require(:variant).permit(permitted_variant_attributes)
      end
    end
  end
end
