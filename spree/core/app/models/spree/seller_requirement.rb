# frozen_string_literal: true

module Spree
  # One thing a marketplace asks of its sellers before it will let them
  # trade — accepting the terms, giving a returns address, uploading a
  # business registration (docs/plans/6.0-seller-onboarding-requirements.md).
  #
  # A row is a configured instance of a *kind* (an STI subclass registered in
  # `Spree.seller_requirements`), so the operator composes the checklist from
  # the dashboard and only a genuinely new kind of check needs code. Rows are
  # configuration; what a particular seller has done about one is either
  # computed from their own data or recorded as a
  # {Spree::SellerRequirementSubmission}.
  class SellerRequirement < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::PreferenceSchema
    include Spree::Metadata

    has_prefix_id :selreq

    acts_as_list scope: :store

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store', inverse_of: :seller_requirements
    has_many :submissions, class_name: 'Spree::SellerRequirementSubmission',
                           foreign_key: :seller_requirement_id, inverse_of: :requirement, dependent: :destroy

    #
    # Validations
    #
    validates :type, presence: true
    validate :type_must_be_registered
    # Most kinds answer one question, so a second row of the same kind would
    # either repeat it or contradict it. The generic kinds — where the
    # question is the operator's own words — opt out.
    validates :type, uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope] },
                     unless: -> { self.class.allow_multiple? }
    # A kind that can appear more than once has nothing else to tell the
    # seller apart by, so its label is the row's own.
    validates :name, presence: true, if: -> { self.class.allow_multiple? }

    registers_subclasses_via { Spree.seller_requirements }

    #
    # Scopes
    #
    scope :active, -> { where(active: true) }
    scope :required, -> { where(required: true) }

    # The kinds a marketplace starts with, in the order a seller meets them:
    # agree to the terms, say who you are, tell us where to invoice and where
    # returns go, then list something.
    #
    # Only the kinds that ask a question core already knows how to answer.
    # The generic ones (an attestation, a document, a manual check) are absent
    # on purpose — they mean nothing until the operator has written what they
    # are asking for.
    DEFAULT_KINDS = %w[
      Spree::SellerRequirements::AcceptTerms
      Spree::SellerRequirements::CompleteProfile
      Spree::SellerRequirements::BillingAddress
      Spree::SellerRequirements::ReturnsAddress
      Spree::SellerRequirements::MinimumProducts
    ].freeze

    # Writes the default checklist for a store, skipping kinds it already
    # has. Idempotent, so a store seeded before a kind existed picks it up on
    # the next run — but a requirement the operator deleted stays deleted
    # only until then, which is the same bargain the seeded commission rate
    # makes.
    #
    # @param store [Spree::Store]
    # @return [Array<Spree::SellerRequirement>] the rows created
    def self.provision_defaults(store)
      registered = Spree.seller_requirements.map(&:to_s)
      # `reorder(nil)`: the association orders by position, and PostgreSQL
      # refuses SELECT DISTINCT with an ORDER BY on a column it does not select.
      existing = store.seller_requirements.where(type: DEFAULT_KINDS).reorder(nil).distinct.pluck(:type)

      ((DEFAULT_KINDS & registered) - existing).map do |kind|
        store.seller_requirements.create!(type: kind)
      end
    end

    # @return [String] the localized name of the kind, used by operator pickers
    def self.human_name
      Spree.t("seller_requirement_types.#{api_type}.name", default: api_type.titleize)
    end

    # @return [String] the localized description of the kind
    def self.human_description
      Spree.t("seller_requirement_types.#{api_type}.description", default: '')
    end

    # Whether the operator may configure this kind more than once per store.
    # True for the kinds whose meaning comes from the operator's own copy.
    #
    # @return [Boolean]
    def self.allow_multiple?
      false
    end

    # Whether a seller can record having done this themselves. False for
    # computed kinds, where a submission would be a second, disagreeing
    # answer to a question the data already settles.
    #
    # @return [Boolean]
    def self.accepts_submissions?
      false
    end

    # Whether a seller's submission waits for someone to confirm it.
    #
    # @return [Boolean]
    def self.reviewed_by_operator?
      false
    end

    # Whether a submission has to carry a file to mean anything. Declared by
    # the kind rather than tested for by class, so a gem shipping its own
    # document-style kind gets the same enforcement.
    #
    # @return [Boolean]
    def self.requires_file?
      false
    end

    # Content types a submission's file may carry. Empty accepts anything.
    # Declared beside {.requires_file?} so a kind that collects files gets
    # both halves of the contract rather than only the one it remembered.
    #
    # @return [Array<String>]
    def self.accepted_content_types
      []
    end

    delegate :accepted_content_types, to: :class

    # @return [String] what the seller sees; the kind's name unless the
    #   operator wrote their own
    def display_name
      name.presence || self.class.human_name
    end

    # @return [String, nil]
    def display_description
      description.presence || self.class.human_description.presence
    end

    # Whether this requirement applies to the given seller at all. A kind
    # narrows itself here — a payout-account kind only applies once the store
    # has a payout provider — and a requirement that does not apply is absent
    # from the checklist rather than shown as unmet.
    #
    # @param _seller [Spree::Seller]
    # @return [Boolean]
    def applicable?(_seller)
      true
    end

    # Whether this requirement stands met for the seller.
    #
    # A waiver settles it whatever the kind would otherwise say: the operator
    # is recording that they dealt with this outside the marketplace, and a
    # kind reading its own data — the terms column, the address — would
    # never see that. Not overridable for exactly that reason; kinds
    # override {#met_by_seller?} instead.
    #
    # Whether this evaluation may answer from what Spree already knows rather
    # than asking the outside world. Set by `Spree::Sellers::Requirements` for
    # a listing, where one network call per row is the difference between a
    # page that loads and one that does not. A kind that never leaves the
    # database can ignore it; one that calls a provider should read the value
    # it last recorded instead.
    #
    # False everywhere it matters — the two approval gates and a seller's own
    # page ask for the current answer.
    attr_accessor :prefer_cached

    # @param seller [Spree::Seller]
    # @return [Boolean]
    def satisfied?(seller)
      return true if latest_submission(seller)&.waived?

      met_by_seller?(seller)
    end

    # Whether the seller themselves has met this requirement. Computed kinds
    # override this to read seller data; the default answers from the latest
    # submission, which is what the attested and verified kinds need.
    #
    # @param seller [Spree::Seller]
    # @return [Boolean]
    def met_by_seller?(seller)
      submission = latest_submission(seller)

      submission.present? && submission.satisfies_requirement?
    end

    # The seller's standing on this requirement.
    #
    # `pending` means someone else has to act — an operator review, a
    # provider still working through its own checks — which is worth telling
    # the seller apart from "you have not done this yet".
    #
    # @param seller [Spree::Seller]
    # @return [String] complete | incomplete | pending | rejected
    def status_for(seller)
      return Spree::SellerRequirementStatus::COMPLETE if satisfied?(seller)

      case latest_submission(seller)&.status
      when 'pending' then Spree::SellerRequirementStatus::PENDING
      when 'rejected' then Spree::SellerRequirementStatus::REJECTED
      else Spree::SellerRequirementStatus::INCOMPLETE
      end
    end

    # Somewhere for the seller to go to get this done — a hosted onboarding
    # link, for instance. Nil when the seller finishes it inside their own
    # panel, which is the usual case.
    #
    # @param _seller [Spree::Seller]
    # @return [String, nil]
    def action_url(_seller)
      nil
    end

    # Why this line is not done, when the answer is somewhere the seller
    # cannot see. Nil for every kind whose own description already says what
    # is wanted, which is nearly all of them — a requirement asking for an
    # address explains itself.
    #
    # @param _seller [Spree::Seller]
    # @return [Hash, nil] `{ state:, message: }`
    def blocker(_seller)
      nil
    end

    # The submission that decides this requirement's standing for a seller:
    # the most recent one. Earlier rows are the audit trail.
    #
    # Read through the seller rather than through this requirement: a seller
    # has a handful of submissions, a requirement has one per seller on the
    # marketplace, and evaluating a checklist asks about one seller. The
    # seller's association loads once and every requirement reads from it.
    #
    # @param seller [Spree::Seller]
    # @return [Spree::SellerRequirementSubmission, nil]
    def latest_submission(seller)
      return nil if seller.nil?

      seller.requirement_submissions
            .select { |submission| submission.seller_requirement_id == id }
            .max_by { |submission| [submission.created_at, submission.id] }
    end

    private

    def type_must_be_registered
      return if type.blank?
      return if Spree.seller_requirements.any? { |kind| kind.to_s == type }

      errors.add(
        :type,
        Spree.t(:invalid_seller_requirement, scope: [:errors, :messages],
                                             default: 'is not a registered seller requirement')
      )
    end
  end
end
