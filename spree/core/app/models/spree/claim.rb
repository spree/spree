module Spree
  # A customer reports a problem — damaged, missing or wrong item — and the
  # merchant makes it right without necessarily asking for the goods back.
  #
  # This has no equivalent in the legacy chain: merchants either created a
  # manual order or faked it through a return authorization received
  # immediately. Transitions are workflows
  # (docs/plans/6.0-returns-exchanges-claims.md).
  class Claim < Spree.base_class
    has_prefix_id :claim

    include Spree::Core::NumberGenerator.new(prefix: 'CLM', length: 9)
    include Spree::NumberIdentifier
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :open, :approved, :resolved, :denied, :canceled, default: :open

    # Configuration, not a frozen constant — a merchant can add a type
    # without reopening core. Types are pure labels with no per-type
    # behaviour, so extending the list needs no accompanying workflow.
    class_attribute :claim_types, default: %w[damaged missing wrong_item other]

    # Unlike claim types, each resolution drives real behaviour in
    # Spree::Claims::Resolve, so this stays closed — an unrecognised value
    # would silently do nothing.
    RESOLUTIONS = %w[refund replacement refund_and_replacement].freeze

    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :claims
    belongs_to :reason, class_name: 'Spree::ReturnAuthorizationReason', optional: true
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true

    has_many :claim_line_items, class_name: 'Spree::ClaimLineItem',
                                dependent: :destroy, inverse_of: :claim
    has_many :refunds, class_name: 'Spree::Refund', as: :originator, dependent: :nullify

    validates :order, :claim_type, presence: true
    validates :claim_line_items, presence: true, on: :create
    validates :claim_type, inclusion: { in: ->(record) { record.class.claim_types } }
    validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true

    accepts_nested_attributes_for :claim_line_items, allow_destroy: true

    delegate :currency, to: :order

    self.whitelisted_ransackable_attributes = %w[number status claim_type created_at]
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
