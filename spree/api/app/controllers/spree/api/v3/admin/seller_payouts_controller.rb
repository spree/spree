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

          before_action :set_resource, only: [:complete]

          # PATCH /api/v3/admin/seller_payouts/:id/complete
          #
          # What the built-in provider waits for: the operator saying the bank
          # transfer went out, with the reference it went out under.
          def complete
            result = Spree.seller_payout_complete_workflow.call(
              seller_payout: @resource,
              reference: params[:reference]
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

          def collection_includes
            [:seller, :transfers]
          end
        end
      end
    end
  end
end
