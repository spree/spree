module Spree
  module Api
    module V3
      module OrderConcern
        extend ActiveSupport::Concern

        # Allow access to order via order token for guests or authenticated users
        def authorize_order_access!
          authorize!(:update, @order, order_token)
        end

        protected

        # Finds order by number from params
        # Uses params[:order_id] for nested resources (line items, payments, etc.)
        def set_order
          @order = current_store.orders.friendly.find(params[:order_id])
        end

        def order_token
          # Check X-Spree-Order-Token header first
          header = request.headers['X-Spree-Order-Token']
          return header if header.present?

          # Fallback to query param
          params[:token]
        end
      end
    end
  end
end
