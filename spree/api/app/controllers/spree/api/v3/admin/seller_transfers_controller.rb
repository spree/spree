module Spree
  module Api
    module V3
      module Admin
        # What each seller has earned, order by order.
        #
        # Read-only, enforced by the routes: a transfer records money that
        # moved. Correcting one is a reversal — another row, written by the
        # refund that caused it — rather than an edit.
        class SellerTransfersController < ResourceController
          scoped_resource :payouts

          protected

          def model_class
            Spree::SellerTransfer
          end

          def serializer_class
            Spree.api.admin_seller_transfer_serializer
          end

          def scope
            super.for_store(current_store)
          end

          def collection_includes
            [:seller, :order, :payout]
          end
        end
      end
    end
  end
end
