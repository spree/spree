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
