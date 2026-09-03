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
        # as missing rather than denied. Drafts are not this seller's either —
        # neither an in-flight checkout nor the operator's working document —
        # and are unreachable from every endpoint on this branch.
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
          # A seller withdrawing from an order they cannot fulfil, naming a
          # reason from the marketplace's own list.
          #
          # Deliberately takes no `refund_payments` or `refund_amount`: the
          # workflow releases the authorization either way, but returning money
          # already taken is the operator's decision, and leaving the arguments
          # off is what keeps that true rather than a default a caller could
          # override.
          def cancel
            with_order_lock do
              result = Spree.order_cancel_workflow.call(
                order: @resource,
                canceler: try_spree_current_user,
                reason: cancel_reason,
                note: params[:cancel_note].presence,
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

          # The same exclusion the nested endpoints get from
          # `current_seller_orders`, applied over the inherited scope so its
          # includes and preloading survive.
          def scope
            super.not_drafts
          end

          def collection_includes
            [:line_items, :customer, :channel]
          end

          private

          # The reason a seller picked, resolved through the store's own list so
          # a reason belonging to another store reads as missing. Optional —
          # the workflow accepts a cancellation with none.
          def cancel_reason
            id = params[:cancel_reason_id].presence
            return if id.nil?

            current_store.order_cancellation_reasons.find_by_prefix_id!(id)
          end

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
