module Spree
  module Api
    module V3
      module OrderConcern
        extend ActiveSupport::Concern

        # Allow access to order via order token for guests or authenticated users
        def authorize_order_access!
          # Allow if user is authenticated and owns the order
          return if current_user && @order.user == current_user

          # Allow guest access via order token
          order_token = extract_order_token

          unless order_token.present? && @order.token == order_token
            render_error(
              code: ERROR_CODES[:access_denied],
              message: 'Access denied',
              status: :forbidden
            )
            return false
          end
        end

        protected

        # Finds order by number from params
        # Uses params[:order_id] for nested resources (line items, payments, etc.)
        # Uses params[:id] for order resource endpoints
        def set_order
          order_param = params[:order_id].presence || params[:id]
          @order = current_store.orders.incomplete.friendly.find(order_param)
        end

        private

        def extract_order_token
          # Check X-Spree-Order-Token header first
          header = request.headers['X-Spree-Order-Token']
          return header if header.present?

          # Fallback to query param
          params[:order_token]
        end
      end
    end
  end
end
