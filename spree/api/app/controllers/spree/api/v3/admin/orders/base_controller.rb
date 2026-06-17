module Spree
  module Api
    module V3
      module Admin
        module Orders
          class BaseController < ResourceController
            include Spree::Api::V3::OrderLock

            before_action :authorize_order_access!

            scoped_resource :orders

            protected

            def set_parent
              @parent = current_store.orders.find_by_prefix_id!(params[:order_id])
              @order = @parent
            end

            # Read actions require only :show on the parent order; every write
            # (create/update/destroy and custom member actions like capture,
            # void, fulfill, split, apply gift card / store credit) requires
            # :update, so a read-only role can't mutate an order it can view.
            # Subclasses with custom read-only actions extend +read_actions+.
            def authorize_order_access!
              authorize_parent!(@parent)
            end
          end
        end
      end
    end
  end
end
