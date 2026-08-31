module Spree
  module Api
    module V3
      module Store
        module Customer
          class OrdersController < ResourceController
            prepend_before_action :require_authentication!

            protected

            # Order history is a receipt surface — see StorefrontGating#renders_receipts?.
            def renders_receipts?
              true
            end

            def model_class
              Spree::Order
            end

            def serializer_class
              Spree.api.order_serializer
            end

            def set_parent
              @parent = current_user
            end

            def parent_association
              :orders
            end

            def scope
              super.for_store(current_store).complete
            end

            # The withdrawal deadline reads both on every row, so without
            # these an order history pays two queries per order.
            def collection_includes
              super + [:market, :fulfillments]
            end
          end
        end
      end
    end
  end
end
