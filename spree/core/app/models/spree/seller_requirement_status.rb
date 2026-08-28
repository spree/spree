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

    # Why this line is stuck, when the reason lives somewhere the seller
    # cannot see — a payout provider still checking their identity, say.
    #
    # `state` is one of `action` (they must do something), `pending` (the
    # provider is looking, and nobody can hurry it) or `rejected`. `message`
    # is the provider's own sentence when it wrote one: best-effort and
    # unlocalized, so it is shown as detail beside translated copy rather
    # than in place of it.
    #
    # @return [Hash, nil]
    attr_accessor :blocker

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

    # The legal document this line asks for, when its kind asks for one —
    # nil for every other kind.
    #
    # Same job as {#custom_fields}: the value object answers "what does this
    # requirement want", so the seller panel can offer to create that exact
    # document rather than making the seller retype its name.
    #
    # @return [String, nil]
    def required_policy_name
      return nil unless requirement.respond_to?(:required_policy_name)

      requirement.required_policy_name.presence
    end

    # The policy the seller actually published against this line, when they
    # have — nil for every other kind, and nil while the document is still
    # owed.
    #
    # What the operator reads before approving: a line that says "Done"
    # without showing what was written is not something anyone can approve on.
    #
    # @return [Spree::Policy, nil]
    def published_policy
      return @published_policy if defined?(@published_policy)

      name = required_policy_name
      return @published_policy = nil if name.nil? || seller.nil?

      @published_policy = seller.policies.detect do |policy|
        policy.name.to_s.strip.casecmp?(name) && policy.with_body?
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
