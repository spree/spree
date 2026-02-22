module Spree
  module Admin
    module OrderConcern
      extend ActiveSupport::Concern

      included do
        rescue_from ActiveRecord::RecordNotFound, with: :resource_not_found
      end

      protected

      def load_order
        @order = current_store.orders.find_by_prefix_id!(params[:order_id])
        authorize! action, @order
        @order
      end

      def load_order_items
        @line_items = @order.line_items.includes(variant: [:product, :option_values])
        @shipments = @order.shipments.includes(:inventory_units, :selected_shipping_rate,
                                               shipping_rates: [:shipping_method, :tax_rate]).order(:created_at)
        @payments = @order.payments.includes(:payment_method, :source).order(:created_at)
        @refunds = @order.refunds

        @return_authorizations = @order.return_authorizations.includes(:return_items)
        @customer_returns = @order.customer_returns.distinct

        @order_promotions = @order.order_promotions.includes(promotion: :promotion_actions)
        @tax_adjustments = @order.all_adjustments.tax.includes(:source, :adjustable)
      end

      def resource_not_found
        flash[:error] = flash_message_for(model_class.new, :not_found)
        redirect_to spree.admin_orders_path
      end
    end
  end
end
