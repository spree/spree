# frozen_string_literal: true

module Spree
  # A seller asking for a product to go on sale, and what the marketplace
  # made of it (docs/plans/6.0-seller-product-submission.md).
  #
  # The product's own status stays the operational truth — this is the record
  # of how it got there: who submitted, who decided, when, and what they told
  # the seller. The latest row for a product is the live one; the ones before
  # it are the trail.
  #
  # Named for the seller's act rather than the operator's, with the decision
  # riding on it: `Spree::ProductReview` belongs to customer ratings.
  class ProductSubmission < Spree.base_class
    include Spree::HasStatus
    include Spree::Metadata

    has_prefix_id :prodsub

    publishes_lifecycle_events

    # `withdrawn` is the seller taking a submission back before anybody ruled
    # on it, so a `pending` row always means "waiting on the marketplace"
    # rather than "abandoned".
    has_status :pending, :approved, :rejected, :withdrawn, default: :pending

    #
    # Associations
    #
    belongs_to :product, class_name: 'Spree::Product', inverse_of: :all_submissions
    # Set when the row reviews one seller's offer rather than the product
    # itself. The product is named either way, so a marketplace reads the
    # whole trail for a listing from one place
    # (docs/plans/6.0-seller-master-catalog-listings.md, Decision 3).
    belongs_to :variant, class_name: 'Spree::Variant', optional: true, inverse_of: :submissions
    belongs_to :submitted_by, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :reviewed_by, class_name: Spree.admin_user_class.to_s, optional: true

    #
    # Scopes
    #
    # Recency decides which row is live, and rows written in the same request
    # share a timestamp — so `id` breaks the tie rather than leaving the
    # winner to insertion order.
    scope :latest_first, -> { order(created_at: :desc, id: :desc) }


    self.whitelisted_ransackable_attributes = %w[status reviewed_at created_at]

    # A row built through `variant.submissions` names only the variant, and
    # the product column is NOT NULL — so the product comes from the variant
    # rather than from every caller remembering to pass both.
    before_validation :derive_product_from_variant

    # An approval nobody made: the store approves listings automatically, and
    # a blank reviewer must not read as a lost name.
    #
    # @return [Boolean]
    def auto_approved?
      metadata.to_h['auto_approved'].present?
    end

    # The store this belongs to, derived rather than stored — a submission
    # cannot outlive its product or belong to another store's.
    #
    # @return [Spree::Store, nil]
    def store
      product&.store
    end

    # Named explicitly rather than left to the `Spree::Api::V3::` convention:
    # a serializer at that level is picked up by the Store API's generated
    # types and OpenAPI document, and a review decision is not something the
    # storefront has any business describing. The seller's own view is the
    # right shape for an event — it already withholds who decided, which a
    # webhook payload leaving the marketplace should not carry.
    #
    # @return [Class]
    def event_serializer_class
      Spree::Api::V3::Seller::ProductSubmissionSerializer
    end

    private

    def derive_product_from_variant
      return if product_id.present? || variant.nil?

      self.product_id = variant.product_id
    end
  end
end
