module Spree
  module Api
    module V3
      module Admin
        # Settlements to sellers — what has been sent, and what is still owed.
        #
        # A payout is created by the sweep on the seller's own schedule rather
        # than by a caller, so there is no create or update here. The one thing
        # an operator does to a payout is say it landed, which is what the
        # built-in provider expects: it records the settlement and waits to be
        # told the bank transfer went out.
        class SellerPayoutsController < ResourceController
          scoped_resource :payouts

          # PATCH /api/v3/admin/seller_payouts/:id/complete
          #
          # What the built-in provider waits for: the operator saying the bank
          # transfer went out, with the reference it went out under.
          #
          # Authorized as an update, like every other custom member action —
          # naming the action itself would only pass while the ability grants
          # `manage`, and a host narrowing that would get a 403 the scope gate
          # had already allowed.
          def complete
            @resource = find_resource
            authorize! :update, @resource

            result = Spree.seller_payout_complete_workflow.call(
              seller_payout: @resource,
              reference: params[:reference].to_s.presence
            )

            if result.success?
              render json: serialize_resource(result.value)
            else
              render_result_error(result)
            end
          end

          protected

          def model_class
            Spree::SellerPayout
          end

          def serializer_class
            Spree.api.admin_seller_payout_serializer
          end

          def scope
            super.for_store(current_store)
          end

          # Deliberately without `transfers`: the serializer wants their number,
          # not the rows, and a monthly settlement can hold hundreds.
          def collection_includes
            [:seller]
          end

          # One grouped count for the page, handed to the serializer — asking
          # each row for its own would be a query per settlement, and a
          # counter column cannot work here because the sweep claims transfers
          # with `update_all`, which no callback sees.
          def serializer_params
            super.merge(transfer_counts: transfer_counts)
          end

          def transfer_counts
            @transfer_counts ||= Spree::SellerTransfer.where(payout_id: collection.map(&:id)).group(:payout_id).count
          end
        end
      end
    end
  end
end
