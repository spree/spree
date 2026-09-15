module Spree
  module Api
    module V3
      module Seller
        # What this seller has earned, order by order.
        #
        # Read-only: a transfer records money that moved, or is moving, and
        # what corrects it is a reversal — another row, written by the refund
        # — rather than an edit. Rooted in `current_seller.seller_transfers`,
        # so another seller's row is a 404 by construction.
        class TransfersController < Seller::ResourceController
          scoped_resource :seller_earnings

          protected

          def model_class
            Spree::SellerTransfer
          end

          def serializer_class
            Spree.api.seller_transfer_serializer
          end

          def scope
            super.order(created_at: :desc)
          end

          def collection_includes
            [:order, :payout, :reversed_from]
          end

          # The ledger classes belong to `payouts`, the operator's key, which a
          # seller never holds. The question this endpoint asks is "may this
          # seller read their own books", which is what `:seller_earnings`
          # answers; which rows are theirs is the scope above.
          def authorize_resource!(_resource = @resource, action = action_name.to_sym)
            authorize!(action, :seller_earnings)
          end
        end
      end
    end
  end
end
