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
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

        load_orders
      end

      private

      def scope
        current_store.checkouts.accessible_by(current_ability, :index)
      end
    end
  end
end
