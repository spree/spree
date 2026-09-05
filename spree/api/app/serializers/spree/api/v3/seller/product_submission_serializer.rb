module Spree
  module Api
    module V3
      module Seller
        # The marketplace's answer on a listing, as the seller sees it.
        #
        # The reviewer's identity is deliberately absent: a seller needs to
        # know what to change, not which member of the marketplace's staff
        # decided (docs/plans/6.0-seller-product-submission.md).
        class ProductSubmissionSerializer < BaseSerializer
          typelize status: :string,
                   product_id: :string,
                   variant_id: [:string, nullable: true],
                   review_note: [:string, nullable: true],
                   reviewed_at: [:string, nullable: true]

          attributes :status, :review_note,
                     reviewed_at: :iso8601,
                     created_at: :iso8601

          # Carried for the event payload, which is this serializer's other
          # job: a subscriber holding only the submission id would have to
          # fetch the row back to learn which product was decided on.
          attribute :product_id do |submission|
            submission.product&.prefixed_id
          end

          # Set when the decision was about one seller's offer rather than the
          # product itself, so a subscriber can tell the two apart
          # (docs/plans/6.0-seller-master-catalog-listings.md).
          attribute :variant_id do |submission|
            submission.variant&.prefixed_id
          end
        end
      end
    end
  end
end
