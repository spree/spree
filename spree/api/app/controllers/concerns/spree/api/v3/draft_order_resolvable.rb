module Spree
  module Api
    module V3
      # Resolves a draft order a storefront buyer pays for: one raised by
      # staff or an extension, in this store, that the caller owns or holds
      # the order token for. Anything else — another store's order, another
      # buyer's, or a checkout's transient draft — is not found.
      module DraftOrderResolvable
        extend ActiveSupport::Concern

        protected

        # Pass +include_placed: true+ for the idempotent replays (completing
        # again, confirming a payment a webhook already settled), which must
        # still answer once the order is placed.
        #
        # @return [Spree::Order]
        def find_draft_order!(include_placed: false)
          orders = current_store.orders.standalone_drafts
          orders = orders.or(current_store.orders.placed_orders) if include_placed

          @order = storefront_access_policy.scope(orders, token: order_token).
                   find_by_prefix_id!(params[:order_id] || params[:id])
          authorize_storefront_write!(@order, token: order_token) if @order.draft?
          @order
        end
      end
    end
  end
end
