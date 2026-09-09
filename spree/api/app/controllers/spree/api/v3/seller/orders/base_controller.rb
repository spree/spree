module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Anchor for everything nested under one of this seller's orders.
          #
          # Mirrors Admin::Orders::BaseController: the parent order is fetched
          # once here rather than in each controller. The difference is the
          # root — `current_seller_orders`, which is the seller's own orders
          # minus drafts, since neither an in-flight checkout nor the
          # operator's working document is this seller's to act on.
          #
          # Deliberately not a subclass of the admin base: that one resolves
          # through `current_store`, and inheriting its lookups is precisely
          # how a seller would come to read the whole marketplace.
          class BaseController < Seller::ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!

            scoped_resource :orders

            protected

            def set_parent
              @parent = current_seller_orders.find_by_prefix_id!(params[:order_id])
              @order = @parent
            end

            # Reads need only `:show` on the order; every write needs
            # `:update`, so a seller who may only view an order cannot ship,
            # refund or cancel against it. Derived from +read_actions+ rather
            # than a hand-kept list, so a new write action is a write by
            # default instead of silently unauthorized.
            def authorize_order_access!
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
