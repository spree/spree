module Spree
  module Admin
    class OrdersController < Spree::Admin::BaseController
      include Spree::Admin::OrderConcern
      include Spree::Admin::OrdersFiltersHelper

      before_action :initialize_order_events
      before_action :load_order, only: %i[edit cancel resend]
      before_action :load_order_items, only: :edit
      before_action :load_user, only: [:index]

      helper_method :model_class

      def create
        @order = Spree::Order.create(created_by: try_spree_current_user, store: current_store)

        redirect_to spree.edit_admin_order_path(@order)
      end

      def index
        params[:q] ||= {}
        params[:q][:s] ||= 'completed_at desc'

        load_orders
      end

      def cancel
        @order.canceled_by(try_spree_current_user)
        flash[:success] = Spree.t(:order_canceled)
        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      def resend
        @order.deliver_order_confirmation_email
        if @order.errors.any?
          flash[:error] = @order.errors.full_messages.join(', ')
        else
          flash[:success] = Spree.t(:order_email_resent)
        end

        redirect_back fallback_location: spree.edit_admin_order_url(@order)
      end

      private

      def scope
        base_scope = current_store.orders.accessible_by(current_ability, :index)

        if action_name == 'index'
          base_scope.complete
        else
          base_scope
        end
      end

      def order_params
        params[:created_by_id] = try_spree_current_user.try(:id)
        params.permit(:created_by_id, :user_id, :store_id, :channel)
      end

      def load_order
        @order = scope.includes(:adjustments).find_by!(number: params[:id])
        authorize! action, @order
      end

      def load_order_items
        @line_items = @order.line_items.includes(variant: [:product, :option_values])
        @shipments = @order.shipments.includes(:inventory_units, :selected_shipping_rate,
                                               shipping_rates: [:shipping_method, :tax_rate]).order(:created_at)
        @payments = @order.payments.includes(:payment_method, :source).order(:created_at)
        @refunds = @order.refunds

        @return_authorizations = @order.return_authorizations
        @customer_returns = @order.customer_returns
      end

      # Used for extensions which need to provide their own custom event links on the order details view.
      def initialize_order_events
        @order_events = %w{approve cancel resume}
      end

      def model_class
        Spree::Order
      end
    end
  end
end
