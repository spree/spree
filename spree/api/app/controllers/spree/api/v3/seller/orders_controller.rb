module Spree
  module Api
    module V3
      module Seller
        # The orders placed with this seller.
        #
        # On a marketplace a basket spanning several sellers is split into one
        # order each, so a seller's orders are their own rows — not a filtered
        # view of somebody else's. The anchor roots `scope` in
        # `current_seller.orders`, so an id belonging to another seller reads
        # as missing rather than denied.
        #
        # Read and cancel only. Fulfilling is the fulfillments endpoint under
        # the order, and everything that settles money with the customer —
        # approving, resuming, refunds, payments — stays with the operator,
        # who owns that relationship.
        class OrdersController < Seller::ResourceController
          include Spree::Api::V3::OrderLock

          scoped_resource :orders

          before_action :set_resource, only: [:show, :cancel]

          # PATCH /api/v3/seller/orders/:id/cancel
          #
          # A seller withdrawing from an order they cannot fulfil. Restocking
          # and any refund are the workflow's own concern, so a seller cannot
          # cancel without the money and stock following.
          def cancel
            with_order_lock do
              result = Spree.order_cancel_workflow.call(
                order: @resource,
                canceler: try_spree_current_user,
                notify_customer: params[:notify_customer].to_b
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(@resource.errors.presence || result.error)
              end
            end
          end

          protected

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.seller_order_serializer
          end

          def read_actions
            %w[index show]
          end

          # A checkout still in flight is a draft carrying its cart; it is not
          # yet anybody's order and must not appear in a seller's list.
          def scope
            base = super

            base.where(cart_id: nil).or(base.where.not(status: 'draft'))
          end

          def collection_includes
            [:line_items, :customer, :channel]
          end

          private

          def set_resource
            @resource = find_resource
            @order = @resource # OrderLock reads this
            authorize_resource!(@resource)
          end

          # Cancelling is a change to the order, so it needs the write key
          # rather than a key of its own.
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(action == :cancel ? :update : action, resource)
          end
        end
      end
    end
  end
end
