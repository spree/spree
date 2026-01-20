module Spree
  module Admin
    class CheckoutsController < ResourceController
      include Spree::Admin::OrdersFiltersHelper
      include Spree::Admin::TableConcern

      before_action :load_user, only: [:index]

      add_breadcrumb Spree.t(:orders), :admin_orders_path
      add_breadcrumb Spree.t(:draft_orders), :admin_checkouts_path
      add_breadcrumb_icon 'inbox'

      def index
        @orders = @collection
      end

      private

      def scope
        current_store.checkouts.accessible_by(current_ability, :index).includes(collection_includes)
      end

      def collection_default_sort
        'created_at desc'
      end

      def collection_includes
        { user: [] }
      end

      def edit_object_url(object, options = {})
        spree.admin_order_path(object, options)
      end
    end
  end
end
