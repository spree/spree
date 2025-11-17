module Spree
  module Admin
    class CheckoutsController < ResourceController
      include Spree::Admin::OrdersFiltersHelper

      before_action :load_user, only: [:index]

      add_breadcrumb Spree.t(:orders), :admin_orders_path
      add_breadcrumb Spree.t(:draft_orders), :admin_checkouts_path
      add_breadcrumb_icon 'inbox'

      def index
        load_orders
        render template: 'spree/admin/orders/index'
      end

      private

      def scope
        current_store.checkouts.accessible_by(current_ability, :index)
      end
    end
  end
end
