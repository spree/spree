module Spree
  module Api
    module V3
      module OrderConcern
        extend ActiveSupport::Concern

        # Allow access to order via order token for guests or authenticated users
        # Expects @parent to be set to the order
        def authorize_order_access!
          authorize!(:update, @parent, order_token)
        end

        def set_parent
          return if params[:order_id].blank?

          @parent = order_scope.find_by_prefix_id!(params[:order_id])
        end

        def order_scope
          base = current_store.orders
          base = if current_user
                   base.where(user: current_user)
                 elsif order_token.present?
                   base.where(token: order_token)
                 else
                   base.none
                 end
          base.preload_associations_lazily
        end

        protected

        def order_token
          # Check x-spree-order-token header first (lowercase for consistency)
          header = request.headers['x-spree-order-token']
          return header if header.present?

          # Fallback to query params (support both token and order_token)
          params[:order_token].presence || params[:token]
        end
      end
    end
  end
end
