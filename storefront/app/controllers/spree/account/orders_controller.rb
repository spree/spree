module Spree
  module Account
    class OrdersController < BaseController
      def index
        @orders = orders_scope.page(params[:page]).per(25)
      end

      def show
        @order = orders_scope.includes(vendor_orders: [:shipments, :line_items]).find_by!(number: params[:id])
      end

      private

      def accurate_title
        if action_name == 'show'
          Spree.t(:order_details_with_number, number: @order.number)
        else
          Spree.t(:my_orders)
        end
      end
    end
  end
end
