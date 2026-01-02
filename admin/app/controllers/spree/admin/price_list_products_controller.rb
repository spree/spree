module Spree
  module Admin
    class PriceListProductsController < ResourceController
      belongs_to 'spree/price_list', find_by: :id

      def bulk_new
        @price_list = parent
        @currency = params[:currency] || current_store.default_currency
      end

      def bulk_create
        product_ids = params[:product_ids] || []
        currency = params[:currency] || current_store.default_currency

        variant_ids = Spree::Variant.eligible.where(product_id: product_ids).pluck(:id)
        existing_variant_ids = parent.prices.where(currency: currency).pluck(:variant_id)
        new_variant_ids = variant_ids - existing_variant_ids

        new_variant_ids.each do |variant_id|
          parent.prices.create!(
            variant_id: variant_id,
            currency: currency,
            amount: nil
          )
        end

        redirect_to edit_admin_price_list_path(parent), notice: Spree.t(:products_added)
      end

      def bulk_destroy
        product_ids = params[:ids] || []

        parent.prices.joins(:variant).where(spree_variants: { product_id: product_ids }).destroy_all

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to edit_admin_price_list_path(parent), notice: Spree.t(:products_removed) }
        end
      end

      private

      def model_class
        Spree::Product
      end
    end
  end
end
