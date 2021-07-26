module Spree
  module Admin
    class StateChangesController < Spree::Admin::BaseController
      include Spree::Admin::OrderConcern

      before_action :load_order, only: [:index]

      def index
        @state_changes = @order.state_changes.includes(:user).order(created_at: :desc)
      end
    end
  end
end
