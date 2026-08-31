# frozen_string_literal: true

module Spree
  # What a seller did about one requirement, and what the operator made of
  # it (docs/plans/6.0-seller-onboarding-requirements.md).
  #
  # Only the requirements a seller attests to, or someone verifies, need a
  # row: the computed kinds read the seller's own data and would be
  # contradicted by a stored answer. The latest row for a
  # (seller, requirement) pair decides the standing; the ones before it are
  # the record of how the marketplace got there.
  class SellerRequirementSubmission < Spree.base_class
    include Spree::HasStatus
    include Spree::Metadata

    has_prefix_id :selsub

    publishes_lifecycle_events

    # `waived` is the operator excusing one seller from something the store
    # asks of everyone — a requirement they have already satisfied off the
    # marketplace, say. It reads as met without pretending the seller did it.
    has_status :pending, :accepted, :rejected, :waived, default: :pending

    #
    # Associations
    #
    belongs_to :seller, class_name: 'Spree::Seller', inverse_of: :requirement_submissions
    belongs_to :requirement, class_name: 'Spree::SellerRequirement',
                             foreign_key: :seller_requirement_id, inverse_of: :submissions
    belongs_to :submitted_by, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :reviewed_by, class_name: Spree.admin_user_class.to_s, optional: true

    #
    # Attachments
    #
    # Private, and served only through the admin and seller branches: these
    # are business registrations and identity documents.
    has_one_attached :file, service: Spree.private_storage_service_name

    #
    # Validations
    #
    validate :requirement_belongs_to_sellers_store

    # Sellers are the marketplace's lower-trust writers and an operator opens
    # these files on their own machine, so the bytes decide what a file is,
    # not the header the uploader sent. The declared-type check is the gem's;
    # the bytes check is ours (Marcel, in process) so a stock host does not
    # need the Unix `file` command the gem's spoofing_protection option
    # shells out to.
    #
    # The accepted list comes from the requirement's own kind, the same value
    # the seller API serializes so the panel's picker can hint it.
    validates :file,
              content_type: {
                in: ->(record) { record.requirement&.accepted_content_types || [] }
              },
              'spree/bytes_content_type': {
                in: ->(record) { record.requirement&.accepted_content_types || [] }
              },
              size: { less_than_or_equal_to: ->(_record) { Spree::Config.max_seller_document_upload_size } },
              if: -> { file.attached? }

    #
    # Scopes
    #
    scope :for_seller, ->(seller) { where(seller_id: seller.id) }

    self.whitelisted_ransackable_attributes = %w[status created_at reviewed_at]
    self.whitelisted_ransackable_associations = %w[seller requirement]

    # Whether this row counts as the requirement being met.
    #
    # @return [Boolean]
    def satisfies_requirement?
      accepted? || waived?
    end

    private

    # A submission joins a seller to a requirement, and both belong to a
    # store — so a mismatch means one of the two ids came from somewhere it
    # should not have. Cheaper to refuse here than to rely on every caller
    # having scope-fetched both.
    def requirement_belongs_to_sellers_store
      return if seller.nil? || requirement.nil?
      return if seller.store_id == requirement.store_id

      errors.add(:requirement, Spree.t('errors.messages.seller_requirement_store_mismatch',
                                       default: 'must belong to the same store as the seller'))
    end
  end
end
