module Spree
  module Api
    module V3
      module Store
        # The parent of a storefront resource nested under an order: the
        # customer's own completed order, by JWT or by guest token, mirroring
        # Store::OrdersController. Authorization of the nested records is the
        # order's — fetching it is the proof of ownership.
        module CustomerOrderParent
          extend ActiveSupport::Concern

          protected

          def set_parent
            cart_pk = Spree::Cart.decode_own_prefixed_id(params[:order_id])
            @parent = if cart_pk
                        order_scope.find_by!(cart_id: cart_pk)
                      else
                        order_scope.find_by_prefix_id!(params[:order_id])
                      end
          end

          def order_scope
            storefront_access_policy.scope(current_store.orders.complete, token: order_token)
          end

          def set_resource
            @resource = find_resource
          end
        end
      end
    end
  end
end
