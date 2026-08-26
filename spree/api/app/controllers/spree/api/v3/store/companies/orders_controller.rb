module Spree
  module Api
    module V3
      module Store
        module Companies
          # Completed purchases across the node's subtree — every member sees
          # them; per-member narrowing is Enterprise's policy layer.
          class OrdersController < BaseController
            protected

            def model_class
              Spree::Order
            end

            def serializer_class
              Spree.api.order_serializer
            end

            def scope
              current_store.orders.complete.
                where(company_id: @parent.self_and_descendants.select(:id))
            end
          end
        end
      end
    end
  end
end
