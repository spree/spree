module Spree
  module Api
    module V3
      module Store
        module Orders
          # Read-only: an order's registration is the snapshot taken when it was
          # placed, and an invoice has to keep saying what it said.
          class TaxIdentifiersController < Store::BaseController
            # GET /api/v3/store/orders/:order_id/tax_identifier
            def show
              return head :not_found if order.tax_identifier.nil?

              render json: serialize_resource(order.tax_identifier)
            end

            protected

            def serializer_class
              Spree.api.tax_identifier_serializer
            end

            private

            # The order is the customer's own — by JWT or by guest token,
            # mirroring Store::Orders::ReturnsController.
            def order
              @order ||= begin
                cart_pk = Spree::Cart.decode_own_prefixed_id(params[:order_id])
                found = if cart_pk
                          order_scope.find_by!(cart_id: cart_pk)
                        else
                          order_scope.find_by_prefix_id!(params[:order_id])
                        end
                authorize!(:show, found, order_token)
                found
              end
            end

            def order_scope
              base = current_store.orders.complete

              if current_user.present?
                base.where(customer: current_user)
              elsif order_token.present?
                base.where(token: order_token)
              else
                base.none
              end
            end
          end
        end
      end
    end
  end
end
