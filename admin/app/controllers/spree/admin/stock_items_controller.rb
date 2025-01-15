module Spree
  module Admin
    class StockItemsController < ResourceController
      before_action :assign_filter_badges, only: :index

      private

      def update_turbo_stream_enabled?
        true
      end

      def collection
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

        @search = super.accessible_by(current_ability, :update).ransack(params[:q])
        @stock_items = @search.result.
                       joins(:variant).
                       where(spree_variants: { track_inventory: true }).
                       merge(current_store.variants.eligible).
                       includes(:stock_location, [variant: [product: [variants: [:images], master: [:images]], images: []]]).
                       page(params[:page]).
                       per(params[:per_page])
      end

      def assign_filter_badges
        @filter_badges ||= begin
          badges = {}

          if params.dig(:q, :variant_product_name_cont).present?
            badges[:variant_product_name_cont] = { label: Spree.t(:product_name), value: params[:q][:variant_product_name_cont] }
          end

          badges[:variant_sku_cont] = { label: Spree.t(:sku), value: params[:q][:variant_sku_cont] } if params.dig(:q, :variant_sku_cont).present?
          if params.dig(:q, :stock_location_id_eq).present?
            badges[:stock_location_id_eq] = {
              label: Spree.t(:stock_location),
              value: Spree::StockLocation.find(params[:q][:stock_location_id_eq]).name
            }
          end
          badges
        end
      end
    end
  end
end
