module Spree
  module Api
    module V3
      module Store
        module Customer
          # The customer's own purchase history.
          #
          # One row per checkout, never per seller. A basket that reached
          # several sellers divided into one order per seller, but the customer
          # made a single purchase and paid once — so the group holding those
          # orders is what their history lists, with the per-seller orders
          # nested inside it carrying their own items, delivery and tracking
          # (docs/plans/6.0-multi-vendor-marketplace.md, Store API surface).
          class OrdersController < ResourceController
            include Spree::Api::V3::PurchaseSerialization

            prepend_before_action :require_authentication!

            protected

            def model_class
              Spree::Order
            end

            # Every row is still an order, so filtering, sorting and pagination
            # keep working on one relation; which of them stands for a grouped
            # purchase is decided in +scope+, and what it renders as in
            # +purchase_for+.
            def serializer_class
              Spree.api.order_serializer
            end

            def set_parent
              @parent = current_user
            end

            # Orders placed on their own, plus the one order that stands for
            # each divided checkout. Without the second half a split purchase
            # would vanish from the history; without the first it would appear
            # once per seller.
            def scope
              base = super.for_store(current_store).complete

              base.where(order_group_id: nil).or(base.where(id: grouped_representatives(base)))
            end

            # The order a split adopted as its group's first child — the lowest
            # id of the siblings, since the split keeps the paid draft order and
            # builds the rest around it. Its siblings are reached through the
            # group it renders as, never as rows of their own.
            def grouped_representatives(base)
              base.where.not(order_group_id: nil).
                group(:order_group_id).
                select(Arel.sql("MIN(#{Spree::Order.quoted_table_name}.id)"))
            end

            # Newest purchase first — what a history page opens on, and the
            # column it shows the date in. Yields to an explicit `sort`, and
            # breaks ties on id so paging through checkouts placed in the same
            # second can neither repeat a row nor skip one.
            def apply_collection_sort(collection)
              return collection if params[:sort].present?

              orders = Spree::Order.arel_table

              collection.order(orders[:completed_at].desc, orders[:id].desc)
            end

            # A grouped row renders as its group, so the children it nests are
            # loaded with what the order serializer reads off each of them, and
            # the payment the whole checkout was charged comes with the group.
            def collection_includes
              super + [:market, :fulfillments, { order_group: [:payments, { orders: [:market, :fulfillments] }] }]
            end

            # Resolves the group's own id as well, since that is what this list
            # hands back for a divided checkout and what a client asks again
            # with.
            def find_resource
              scope.find_by_prefix_id(params[:id]) ||
                group_scope.find_by_prefix_id(params[:id]) ||
                raise(ActiveRecord::RecordNotFound.new(nil, Spree::Order.name))
            end

            def group_scope
              current_store.order_groups.where(customer: current_user).includes(:payments, orders: [:market, :fulfillments])
            end

            def serialize_collection(collection)
              collection.map { |record| serialize_resource(record) }
            end

            def serialize_resource(resource)
              purchase = purchase_for(resource)
              filter_fields(purchase_serializer_for(purchase).new(purchase, params: serializer_params).to_h)
            end

            # What the caller actually bought, for a row that only stands for it.
            def purchase_for(record)
              record.is_a?(Spree::Order) && record.order_group ? record.order_group : record
            end
          end
        end
      end
    end
  end
end
