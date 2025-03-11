module Spree
  module Account
    class OrdersController < BaseController
      # GET /account/orders
      def index
        @orders = orders_scope.page(params[:page]).per(25)
      end

      # GET /account/orders/:id
      def show
        @order = orders_scope.find_by!(number: params[:id])
        @shipments = @order.shipments
      end

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
    end
  end
end
