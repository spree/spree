module Spree
  module Account
    class OrdersController < BaseController
      before_action :load_order_details, only: :show

      # GET /account/orders
      def index
        @orders = orders_scope.order(created_at: :desc).page(params[:page]).per(25)
      end

      # GET /account/orders/:id
      def show; end

      private

      def accurate_title
        if action_name == 'show'
          "#{Spree.t(:order)} ##{@order.number}"
        else
          Spree.t(:my_orders)
        end
      end

      def orders_scope
        order_finder.new(user: try_spree_current_user, store: current_store).execute
      end

      def order_finder
        Spree::Dependencies.completed_order_finder.constantize
      end

      def load_order_details
        @order = orders_scope.find_by!(number: params[:id])
        @shipments = @order.shipments.includes(:stock_location, :address, selected_shipping_rate: :shipping_method, inventory_units: :line_item)
      end
    end
  end
end
