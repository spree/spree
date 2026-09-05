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
        # Read, cancel, and correct an address. Fulfilling is the
        # fulfillments endpoint under the order, and everything that settles
        # money with the customer — approving, resuming, refunds, payments —
        # stays with the operator, who owns that relationship.
        class OrdersController < Seller::ResourceController
          include Spree::Api::V3::OrderLock

          scoped_resource :orders

          before_action :set_resource, only: [:show, :cancel, :address]

          # PATCH /api/v3/seller/orders/:id/cancel
          #
          # A seller withdrawing from an order they cannot fulfil, naming a
          # reason from the marketplace's own list.
          #
          # `refund_payments` hands back what the buyer paid for these goods.
          # A seller is merchant of record for their own child order, so the
          # party who owes that money back is the party who took it — and on a
          # split checkout the workflow settles through this order's own
          # payment splits, capped at each share, so a seller can never reach
          # a sibling's money.
          #
          # Deliberately takes no `refund_amount`: withdrawing from the whole
          # order returns what that order was paid, and a seller choosing a
          # partial figure is a return, which has its own endpoint and its own
          # bound.
          def cancel
            with_order_lock do
              result = Spree.order_cancel_workflow.call(
                order: @resource,
                canceler: try_spree_current_user,
                reason: cancel_reason,
                note: params[:cancel_note].presence,
                refund_payments: params[:refund_payments].to_b,
                notify_customer: params[:notify_customer].to_b
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(@resource.errors.presence || result.error)
              end
            end
          end

          # PATCH /api/v3/seller/orders/:id/address
          #
          # Corrects where the goods go or who the invoice names. The seller is
          # merchant of record for their own child order, so a delivery address
          # the buyer got wrong is theirs to fix.
          #
          # Its own action rather than a general PATCH: an order's terms are
          # the marketplace's, and a write that took whatever the serializer
          # permits would quietly grow into one a seller could reprice with.
          def address
            # Checked before the lock: an empty payload needs no serialization,
            # and returning out of a locked block is worth avoiding.
            return render_validation_error(missing_address_errors) if sent_addresses.blank?

            # The merge reads the address it is about to replace, so it runs
            # under the order's lock: two corrections landing together would
            # each lay their fields over the same snapshot, and the later one
            # would undo the earlier one's lines.
            with_order_lock do
              if @resource.update(address_params)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
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

          # Either address, as a correction rather than a replacement: the
          # sent fields are laid over what the order already holds, so a
          # request naming one line does not blank out the country and
          # postcode beside it. The nested writer builds a fresh address row
          # either way, which is what keeps a shared customer address book
          # entry from being rewritten by an order-level fix.
          def sent_addresses
            @sent_addresses ||= params.permit(
              shipping_address: address_permitted_keys,
              billing_address: address_permitted_keys
            ).slice(:shipping_address, :billing_address).reject { |_key, value| value.blank? }
          end

          def address_params
            permitted = sent_addresses

            {}.tap do |attributes|
              if permitted[:shipping_address].present?
                attributes[:ship_address_attributes] =
                  merged_address(@resource.ship_address, permitted[:shipping_address])
              end

              if permitted[:billing_address].present?
                attributes[:bill_address_attributes] =
                  merged_address(@resource.bill_address, permitted[:billing_address])
              end
            end
          end

          def merged_address(address, sent)
            current = address ? address.attributes.slice(*address_attribute_names) : {}
            current.merge(sent.to_h)
          end

          # The permitted keys that are real columns; the rest are the writer
          # aliases a client may send, which have no value to carry over.
          def address_attribute_names
            @address_attribute_names ||=
              address_permitted_keys.map(&:to_s) & Spree::Address.column_names
          end

          def address_permitted_keys
            [
              :firstname, :lastname, :first_name, :last_name,
              :address1, :address2, :city,
              :country_code, :state_code,
              :zipcode, :postal_code, :phone, :alternative_phone,
              :state_name, :company, :label
            ]
          end

          # A request naming neither address has asked for nothing; saying so
          # beats a 200 that changed nothing.
          def missing_address_errors
            ActiveModel::Errors.new(@resource).tap do |errors|
              errors.add(:base, :blank, message: 'shipping_address or billing_address is required')
            end
          end

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

          # Cancelling and correcting an address are both changes to the
          # order, so they need the write key rather than a key of their own.
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            authorize!(%i[cancel address].include?(action) ? :update : action, resource)
          end
        end
      end
    end
  end
end
