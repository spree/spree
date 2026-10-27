module Spree
  module Api
    module V3
      module Store
        class OrdersController < Store::BaseController
          include Spree::Api::V3::PurchaseSerialization

          # GET /api/v3/store/orders/:id
          # Single order lookup — accessible via order token (guests) or JWT (authenticated users)
          before_action :find_order!

          # Completed orders are receipts.
          renders_receipts!

          def show
            render json: serializer_class.new(@order, params: serializer_params).to_h
          end

          private

          # The cart's prefixed id stays the client's stable checkout handle.
          # A plain completion leaves the order it created carrying that id
          # (Order#cart_id is unique; the order copies the cart token). A
          # checkout that reached several sellers divided into one order per
          # seller and moved the id up to the group holding them, so the same
          # handle resolves to the group — a confirmation asking what its cart
          # became is answered with the whole purchase either way, never one
          # seller's share of it.
          #
          # The group's own id resolves here too, for a client re-reading what
          # completion handed back, the way +carts#complete+ already accepts it.
          def find_order!
            cart_pk = Spree::Cart.decode_own_prefixed_id(params[:id])
            @order = cart_pk ? find_by_cart!(cart_pk) : find_by_prefixed_id!(params[:id])
          end

          # @return [Spree::Order, Spree::OrderGroup]
          def find_by_cart!(cart_pk)
            scope.find_by(cart_id: cart_pk) || group_scope.find_by(cart_id: cart_pk) || not_found!
          end

          # @return [Spree::Order, Spree::OrderGroup]
          def find_by_prefixed_id!(id)
            scope.find_by_prefix_id(id) || group_scope.find_by_prefix_id(id) || not_found!
          end

          # Neither lookup answered. The caller asked `/orders`, so that is what
          # the 404 names — which of the two ran last is this endpoint's
          # business, and `order_not_found` is the code clients already handle.
          def not_found!
            raise ActiveRecord::RecordNotFound.new(nil, Spree::Order.name)
          end

          # Preloaded lazily, which `collection` would do for a list: this
          # controller loads through `find_order!`, so it asks for it itself.
          # Every association the serializer walks — items, parcels, their
          # rates and discounts — is then fetched once for all the rows that
          # need it, rather than once per row.
          def scope
            storefront_access_policy.
              scope(current_store.orders.complete, token: order_token).
              preload_associations_lazily
          end

          # A group renders every child through the order serializer, so this
          # matters most here: without it each seller in the checkout adds its
          # own round of queries for the same associations.
          def group_scope
            storefront_access_policy.
              scope(current_store.order_groups, token: order_token).
              preload_associations_lazily
          end

          def serializer_class
            purchase_serializer_for(@order)
          end
        end
      end
    end
  end
end
