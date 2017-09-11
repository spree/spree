module Spree
  module Admin
    class StateChangesController < Spree::Admin::BaseController
      before_action :load_order, only: [:index]

      def index
        @state_changes = @order.state_changes.includes(:user).order(created_at: :desc)
      end

      private

      def load_order
        @order = Order.find_by!(number: params[:order_id])
        authorize! action, @order
      end
    end
  end
end
