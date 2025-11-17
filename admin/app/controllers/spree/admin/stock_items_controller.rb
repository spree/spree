module Spree
  module Admin
    class StockItemsController < ResourceController
      include ProductsBreadcrumbConcern

      before_action :add_breadcrumbs

      private

      def update_turbo_stream_enabled?
        true
      end

      def collection
        return @collection if @collection.present?

        @search = scope.accessible_by(current_ability, :update).ransack(params[:q])
        @collection = @search.result.
                       joins(:variant).
                       where(spree_variants: { track_inventory: true }).
                       merge(current_store.variants.eligible).
                       includes(collection_includes).
                       page(params[:page]).
                       per(params[:per_page])
      end

      def collection_includes
        {
          stock_location: [],
          variant: [option_values: :option_type, product: [variant_images: [], variants: [:images], master: [:images]], images: []]
        }
      end

      def add_breadcrumbs
        add_breadcrumb Spree.t(:stock), spree.admin_stock_items_path
        add_breadcrumb Spree.t(:stock_items), spree.admin_stock_items_path
      end

      def permitted_resource_params
        params.require(:stock_item).permit(permitted_stock_item_attributes)
      end
    end
  end
end
