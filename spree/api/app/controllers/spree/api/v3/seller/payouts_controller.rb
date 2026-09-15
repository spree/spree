module Spree
  module Api
    module V3
      module Seller
        # Settlements to this seller — what has been sent, and what is owed.
        #
        # Read-only: a payout is created by the sweep and confirmed by the
        # provider or the operator, never by the seller.
        class PayoutsController < Seller::ResourceController
          scoped_resource :seller_earnings

          protected

          def model_class
            Spree::SellerPayout
          end

          def serializer_class
            Spree.api.seller_payout_serializer
          end

          def scope
            super.order(created_at: :desc)
          end

          # See TransfersController: the model class is the operator's subject.
          def authorize_resource!(_resource = @resource, action = action_name.to_sym)
            authorize!(action, :seller_earnings)
          end

          # One grouped count for the page rather than a query per settlement
          # (the sweep claims transfers with `update_all`, so no counter column
          # could stay right). A single payout read asks for its own.
          def serializer_params
            return super unless action_name == 'index'

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
