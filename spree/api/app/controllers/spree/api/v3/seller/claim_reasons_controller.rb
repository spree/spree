module Spree
  module Api
    module V3
      module Seller
        # What went wrong with a delivery, as the marketplace defines it.
        #
        # Read-only: the vocabulary is the operator's, and a seller picks from
        # it while filing a return. Gated by `orders` rather than `settings` —
        # a seller reads these to fill in a form on their own order, and
        # `settings` is closed to the seller audience entirely.
        #
        # Store-scoped rather than seller-scoped, because these are the store's
        # own rows; retired reasons are hidden so a seller cannot file against
        # vocabulary the operator has withdrawn.
        class ClaimReasonsController < Seller::ResourceController
          scoped_resource :orders

          protected

          def model_class
            Spree::ClaimReason
          end

          def serializer_class
            Spree.api.seller_reason_serializer
          end

          def read_actions
            %w[index]
          end

          def scope
            current_store.claim_reasons.active
          end
        end
      end
    end
  end
end
