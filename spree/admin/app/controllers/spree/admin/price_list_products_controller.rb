module Spree
  module Admin
    class PriceListProductsController < ResourceController
      include BulkOperationsConcern

      belongs_to 'spree/price_list', find_by: :prefix_id

      before_action :set_price_list

      # GET /admin/price_lists/:price_list_id/products/bulk_new
      def bulk_new
        @currency = params[:currency] || current_store.default_currency
      end

      # POST /admin/price_lists/:price_list_id/products/bulk_create.turbo_stream
      def bulk_create
        @price_list.add_products(bulk_collection.pluck(:id))

        @collection = collection

        flash.now[:success] = Spree.t(:products_added)
      end

      # DELETE /admin/price_lists/:price_list_id/products/bulk_destroy.turbo_stream
      def bulk_destroy
        @price_list.remove_products(bulk_collection.pluck(:id))
        flash.now[:success] = Spree.t(:products_removed)
      end

      private

      def set_price_list
        @price_list = parent
      end

      def model_class
        Spree::Product
      end

      def scope
        parent.products.distinct
      end

      def edit_object_url(object, options = {})
        spree.edit_admin_product_path(object, options)
      end
    end
  end
end
