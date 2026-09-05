module Spree
  module Api
    module V3
      module Store
        module Customer
          class OrdersController < ResourceController
            prepend_before_action :require_authentication!

            # Order history is a receipt surface.
            renders_receipts!

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

            def scope
              super.for_store(current_store).complete
            end
          end
        end
      end
    end
  end
end
