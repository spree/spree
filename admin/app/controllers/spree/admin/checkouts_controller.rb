module Spree
  module Admin
    class CheckoutsController < BaseController
      include Spree::Admin::OrdersFiltersHelper

      before_action :load_user, only: [:index]
      before_action :assign_filter_badges, only: :index

      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'created_at desc'

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
