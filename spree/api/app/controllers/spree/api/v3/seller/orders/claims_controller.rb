module Spree
  module Api
    module V3
      module Seller
        module Orders
          # Something went wrong with a delivery on one of this seller's
          # orders, and the seller makes it right.
          #
          # The workflows are the operator's, shared through the concern, so a
          # claim settled here credits and restocks exactly as it does when
          # the marketplace handles it. What is here is what makes it the
          # seller's: the order comes from `current_seller_orders`, so a claim
          # on somebody else's order reads as missing rather than denied, and
          # a replacement may only be promised out of this seller's catalogue.
          class ClaimsController < BaseController
            include Spree::Api::V3::Orders::ClaimActions

            before_action :set_resource, only: [:show, :approve, :resolve, :deny, :cancel]

            protected

            def serializer_class
              Spree.api.seller_claim_serializer
            end

            def collection_includes
              [:reason, { claim_line_items: [:variant, :line_item, :replacement_variant] }]
            end

            private

            # The seller's own catalogue: a replacement is stock this seller
            # sends, so a variant belonging to another seller is not theirs to
            # promise.
            def replacement_variant_for(variant_id)
              return nil if variant_id.blank?

              current_seller.variants.find_by_prefix_id!(variant_id)
            end
          end
        end
      end
    end
  end
end
