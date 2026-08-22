# frozen_string_literal: true

module Spree
  # One line of a seller's onboarding checklist: a requirement evaluated
  # against a seller. A value object — the answer is derived from the
  # seller's own data and their submissions every time it is asked for, so
  # there is nothing here worth storing and a stored copy would go stale the
  # moment a product or an address changed.
  #
  # See {Spree::Sellers::Requirements}, which builds these.
  class SellerRequirementStatus
    include ActiveModel::Model
    include ActiveModel::Attributes

    COMPLETE = 'complete'
    INCOMPLETE = 'incomplete'
    PENDING = 'pending'
    REJECTED = 'rejected'

    STATUSES = [COMPLETE, INCOMPLETE, PENDING, REJECTED].freeze

    # The requirement's prefixed id, so a client can act on it.
    attribute :id, :string
    # The kind, e.g. 'accept_terms' — what a frontend keys presentation off.
    attribute :kind, :string
    attribute :name, :string
    attribute :description, :string
    attribute :required, :boolean, default: true
    attribute :position, :integer
    attribute :status, :string
    attribute :action_url, :string

    # The submission behind the status, when there is one.
    # @return [Spree::SellerRequirementSubmission, nil]
    attr_accessor :submission

    # The requirement this was evaluated from.
    #
    # Carried so a serializer can ask the kind its own questions — which
    # custom fields it names, whether it takes a file — without re-fetching a
    # row the evaluator has already loaded. Not serialized itself: what a
    # client needs is the answers, not the configuration row.
    #
    # @return [Spree::SellerRequirement, nil]
    attr_accessor :requirement

    # The seller this was evaluated against, so kind-specific readers can ask
    # about them without the caller passing them a second time.
    #
    # @return [Spree::Seller, nil]
    attr_accessor :seller

    # The custom fields this line asks for, each paired with the seller's
    # current answer — empty for every kind that asks for none.
    #
    # Built here rather than in the serializer because it is the answer to
    # "what does this requirement want", which is the value object's job; the
    # serializer only decides how to render it.
    #
    # @return [Array<Hash>] `{ definition:, custom_field: }` pairs
    def custom_fields
      return @custom_fields if defined?(@custom_fields)
      return @custom_fields = [] if seller.nil? || !requirement.respond_to?(:custom_field_definitions)

      answered = seller.custom_fields.index_by(&:custom_field_definition_id)

      @custom_fields = requirement.custom_field_definitions.map do |definition|
        { definition: definition, custom_field: answered[definition.id] }
      end
    end

    # ActiveModel::Attributes gives readers, not predicates.
    def required?
      !!required
    end

    def complete?
      status == COMPLETE
    end

    # Whether this is standing between the seller and approval.
    #
    # @return [Boolean]
    def blocking?
      required? && !complete?
    end
  end
end
