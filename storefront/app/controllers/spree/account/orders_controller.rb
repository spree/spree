module Spree
  module Account
    class OrdersController < BaseController
      def index
        @orders = orders_scope.page(params[:page]).per(25)
      end

      def show
        @order = orders_scope.find_by!(number: params[:id])
        @shipments = @order.shipments
      end

      private

      def accurate_title
        if action_name == 'show'
          Spree.t(:order_details_with_number, number: @order.number)
        else
          Spree.t(:my_orders)
        end
      end

      def orders_scope
        try_spree_current_user.completed_orders.for_store(current_store).order(completed_at: :desc)
      end
    end
  end
end
