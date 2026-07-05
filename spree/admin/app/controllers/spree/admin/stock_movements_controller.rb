module Spree
  module Admin
    class StockMovementsController < ResourceController
      include ProductsBreadcrumbConcern
      include TableConcern

      before_action :add_breadcrumbs

      private

      def collection_default_sort
        'created_at desc'
      end

      def scope
        super.joins(stock_item: [:variant, :stock_location]).
          merge(current_store.variants.eligible).
          reorder('')
      end

      def collection_includes
        {
          stock_item: {
            stock_location: [],
            variant: [option_values: :option_type, product: [variants: [:images], master: [:images]], images: []]
          },
          originator: []
        }
      end

      def add_breadcrumbs
        add_breadcrumb Spree.t(:stock), spree.admin_stock_items_path
        add_breadcrumb Spree.t(:stock_movements), spree.admin_stock_movements_path
      end
    end
  end
end
