module Spree
  module Admin
    class StockItemsController < ResourceController
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
    end
  end
end
