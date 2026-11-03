module Spree
  module Api
    module V3
      module Store
        # The customer's side of returns, exchanges and claims. Every record
        # hangs off an order the customer owns — by JWT or by guest token,
        # mirroring Store::OrdersController — and that ownership is the whole
        # authorization: the scope is that order's own records.
        #
        # Opening a record is the customer's; approving, receiving and refunding
        # stay with the merchant, through the Admin API. Withdrawing a request
        # is CustomerWithdrawal.
        module CustomerPostSale
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

          # Authorization is the parent order's: set_parent already proved this
          # customer owns it, and the scope is that order's own records.
          def set_resource
            @resource = find_resource
          end

          def order_scope
            storefront_access_policy.scope(current_store.orders.complete, token: order_token)
          end

          def create_params
            @create_params ||= params.permit(*declared_permitted_attributes)
          end

          # The units coming back, resolved through the customer's own order.
          #
          # @return [Spree::FulfillmentItem]
          def fulfillment_item_for(id)
            @parent.fulfillment_items.find_by_prefix_id!(id)
          end

          # Read through the store's active reasons, so one belonging to another
          # store, or one the merchant retired, 404s rather than being attached.
          #
          # @param association [Symbol] :return_reasons or :claim_reasons
          def reason_for_create(association = :return_reasons)
            return nil if create_params[:reason_id].blank?

            current_store.public_send(association).active.find_by_prefix_id!(create_params[:reason_id])
          end

        end
      end
    end
  end
end
