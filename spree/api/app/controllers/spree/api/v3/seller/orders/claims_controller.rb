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

            request_params :claim do |body|
              body.attribute :items, :array, required: true do |item|
                item.attribute :line_item_id, :id, required: true
                item.attribute :quantity, :integer, required: true
                item.attribute :description, :string, nullable: true
                item.attribute :send_replacement, :boolean
                item.attribute :replacement_variant_id, :id,
                  nullable: true,
                  description: "One of this seller's own variants."
                item.attribute :refund_amount, :decimal, nullable: true
              end
              body.attribute :reason_id, :id, nullable: true
              body.attribute :memo, :string, nullable: true
            end

            request_params 'ClaimResolveParams', action: :resolve do |body|
              body.attribute :resolution, :string,
                required: true,
                choices: %w[refund replacement refund_and_replacement]
              body.attribute :refund_method, :string,
                choices: %w[original_payment store_credit],
                description: 'Defaults to `store_credit`.'
              body.attribute :amount, :decimal, nullable: true
              body.attribute :replacement_line_item_ids, :array, of: :id,
                description: 'Which claimed lines to replace. Omit to keep the lines the claim was opened with.'
            end

            request_params 'ClaimDenyParams', action: :deny do |body|
              body.attribute :reason, :string, description: 'Recorded on the claim for the customer.'
            end

            request_params 'ClaimCancelParams', action: :cancel do |body|
              body.attribute :reason, :string, description: 'A note on why the claim was canceled.'
            end

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
