# frozen_string_literal: true

module Spree
  # One settlement to one seller: the earnings they had accrued, batched and
  # sent on their own schedule.
  #
  # The second of the ledger's two levels. Transfers credit a seller as each
  # order ships; a payout is the money actually leaving — daily, weekly,
  # monthly, or whenever an operator says so. It names exactly which transfers
  # it settled, so a seller asking "what is this deposit for" has an answer,
  # and so a reversal arriving after a payout closed lands in the next period
  # rather than rewriting a settlement that already happened.
  #
  # Core records both levels for every marketplace. Whether money actually
  # moves is the {Spree::PayoutProvider}'s business: the built-in one records
  # and leaves the operator to pay by bank, while a provider like Stripe
  # Connect performs the transfer itself.
  class SellerPayout < Spree.base_class
    has_prefix_id :vpo

    include Spree::Metadata

    #
    # Associations
    #
    belongs_to :seller, class_name: 'Spree::Seller'
    # What this payout settles. Deliberately nullify rather than destroy: a
    # transfer is the record of an earning and outlives the settlement that
    # paid it, so a deleted payout releases its transfers back to the next
    # sweep instead of erasing what the seller earned.
    has_many :transfers, class_name: 'Spree::SellerTransfer', foreign_key: :payout_id,
                         inverse_of: :payout, dependent: :nullify

    #
    # Validations
    #
    validates :amount, numericality: true
    validates :currency, presence: true
    validates :provider, presence: true

    #
    # Statuses. As with transfers, movement is through workflows rather than a
    # transition graph.
    #
    include Spree::HasStatus
    has_status :pending, :processing, :completed, :failed, default: :pending

    #
    # Scopes
    #
    # Money promised but not yet gone — what an operator's queue is for.
    scope :owed, -> { where(status: %w[pending processing]) }

    self.whitelisted_ransackable_attributes = %w[amount currency status provider reference period_start period_end created_at]
    self.whitelisted_ransackable_associations = %w[seller transfers]

    extend Spree::DisplayMoney
    money_methods :amount

    # @return [BigDecimal] what the transfers this payout holds actually come
    #   to, for checking a stored amount against its parts
    def transfers_total
      transfers.sum(:amount)
    end
  end
end
