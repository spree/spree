# frozen_string_literal: true

module Spree
  # What one seller earned on one order, credited when the goods went out.
  #
  # The first of the ledger's two levels. A seller earns on **fulfillment**,
  # not on payment: the marketplace holds the money until the goods actually
  # ship, and a digital order fulfils immediately so it earns immediately. The
  # second level — {Spree::SellerPayout} — sweeps these into a bank settlement
  # on the seller's own schedule.
  #
  # The amount is the seller's sale less what the marketplace charged them, and
  # is deliberately **payment-source-agnostic**: store credit and gift cards are
  # how the customer paid, which is the platform's funding concern, not the
  # seller's. They are owed their cut either way.
  #
  # A refund writes a second row against the same order rather than editing
  # this one, so what a seller has earned is always the sum of their transfers
  # and the history stays readable.
  class SellerTransfer < Spree.base_class
    has_prefix_id :vtr

    include Spree::Metadata
    # Denormalized from the seller, which never changes store — so the copy
    # cannot drift, and tenancy is structural rather than a subquery every
    # consumer must remember. Always set explicitly from the seller: ledger
    # rows are written by jobs and subscribers, where the request-scoped
    # default store is absent or wrong.
    include Spree::SingleStoreResource

    KINDS = %w[earning refund_reversal].freeze

    #
    # Associations
    #
    belongs_to :seller, class_name: 'Spree::Seller'
    belongs_to :order, class_name: 'Spree::Order'
    # Nil until a sweep settles this transfer; the stamp is what claims it, so
    # a re-run sweep can never batch the same earning twice.
    belongs_to :payout, class_name: 'Spree::SellerPayout', optional: true, inverse_of: :transfers
    belongs_to :reversed_from, class_name: 'Spree::SellerTransfer', optional: true, inverse_of: :reversals
    # What caused a reversal. Nil on an earning, and the reversal's natural
    # key: one clawback per refund, enforced by a unique index.
    belongs_to :refund, class_name: 'Spree::Refund', optional: true
    has_many :reversals, class_name: 'Spree::SellerTransfer', foreign_key: :reversed_from_id,
                         inverse_of: :reversed_from, dependent: :nullify

    #
    # Validations
    #
    validates :amount, numericality: true
    validates :currency, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :provider, presence: true

    #
    # Statuses. No state machine: a transfer moves through the payout
    # workflows, which can explain a refusal, rather than through a transition
    # graph (docs/plans/6.0-service-workflows.md).
    #
    include Spree::HasStatus
    # `processing` is an attempt that failed and will be tried again;
    # `unresolved` is one whose outcome the provider could not report, which
    # nothing may retry until a person establishes what happened.
    has_status :pending, :processing, :completed, :failed, :unresolved, default: :pending

    #
    # Scopes
    #
    scope :earnings, -> { where(kind: 'earning') }
    scope :reversals_only, -> { where(kind: 'refund_reversal') }
    # Safe to ask the provider about again: never sent, or refused outright.
    # Deliberately excludes `unresolved`, where the provider could not say
    # whether the money moved — asking again is how it moves twice.
    scope :retryable, -> { with_status('pending', 'processing') }
    # Earned and confirmed, but not yet swept into a settlement — what the next
    # payout will pick up.
    scope :unsettled, -> { completed.where(payout_id: nil) }

    self.whitelisted_ransackable_attributes = %w[amount currency kind status provider reference created_at]
    self.whitelisted_ransackable_associations = %w[seller order payout refund]

    extend Spree::DisplayMoney
    money_methods :amount

    # What is left of this earning to give back.
    #
    # Original less what reversals have already taken, floored at zero — a
    # refund can never claw back more than the seller was credited, however
    # many times the order is refunded.
    #
    # @return [BigDecimal]
    def reversible_amount
      return 0.to_d unless earning?

      [amount - reversals.sum(:amount).abs, 0].max
    end

    # @return [Boolean]
    def earning?
      kind == 'earning'
    end
  end
end
