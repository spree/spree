module Spree
  # A customer reports a problem with a delivery and the merchant makes it
  # right without necessarily asking for the goods back. What went wrong is
  # recorded on {Spree::ClaimReason}, the merchant-owned vocabulary.
  #
  # New in 6.0 — there was previously no way to model "send a replacement
  # without asking for the original back". Transitions are workflows
  # (docs/plans/6.0-returns-exchanges-claims.md).
  class Claim < Spree.base_class
    has_prefix_id :claim

    has_spree_number prefix: 'CLM'
    include Spree::NumberIdentifier
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :open, :approved, :resolved, :denied, :canceled, default: :open

    # Each resolution drives real behaviour in Spree::Claims::Resolve, so this
    # stays closed — an unrecognised value would silently do nothing.
    RESOLUTIONS = %w[refund replacement refund_and_replacement].freeze

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :claims
    belongs_to :reason, class_name: 'Spree::ClaimReason', optional: true, inverse_of: :claims
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :claim_line_items, class_name: 'Spree::ClaimLineItem',
                                dependent: :destroy, inverse_of: :claim
    has_many :refunds, class_name: 'Spree::Refund', as: :originator, dependent: :nullify

    validates :claim_line_items, presence: true, on: :create
    validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true

    accepts_nested_attributes_for :claim_line_items, allow_destroy: true

    delegate :currency, to: :order

    self.whitelisted_ransackable_attributes = %w[number status created_at]
    self.whitelisted_ransackable_associations = %w[order reason]

    def refund_total
      claim_line_items.sum(&:refund_amount)
    end

    def display_refund_total
      Spree::Money.new(refund_total, currency: currency)
    end

    def replacement_line_items
      claim_line_items.select(&:send_replacement)
    end
  end
end
