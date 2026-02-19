module Spree
  module Api
    module V3
      module Store
        module Customer
          class OrdersController < ResourceController
            prepend_before_action :require_authentication!

            protected

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

            # Override scope to return only current user's orders for current store
            def scope
              current_user.orders
                          .for_store(current_store)
                          .preload_associations_lazily
            end
          end
        end
      end
    end
  end
end
