module Spree
  module Admin
    class PriceListProductsController < ResourceController
      belongs_to 'spree/price_list', find_by: :id

      # GET /admin/price_lists/:price_list_id/products/bulk_new
      def bulk_new
        @price_list = parent
        @currency = params[:currency] || current_store.default_currency
      end

      # POST /admin/price_lists/:price_list_id/products/bulk_create.turbo_stream
      def bulk_create
        parent.add_products(params[:product_ids])

        @collection = collection
        @price_list = parent

        flash.now[:success] = Spree.t(:products_added)
      end

      # DELETE /admin/price_lists/:price_list_id/products/bulk_destroy.turbo_stream
      def bulk_destroy
        parent.remove_products(params[:ids])
      end

      private

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
