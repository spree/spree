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
    # Denormalized from the seller, which never changes store — so the copy
    # cannot drift, and tenancy is structural rather than a subquery every
    # consumer must remember. Always set explicitly from the seller: ledger
    # rows are written by jobs and subscribers, where the request-scoped
    # default store is absent or wrong.
    include Spree::SingleStoreResource

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
    has_status :pending, :processing, :completed, :failed, :unresolved, default: :pending

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

    # Gives up on this settlement and puts its earnings back.
    #
    # Releasing them is what makes a failure recoverable, and it is the one
    # thing a caller must not forget: a sweep only ever collects unstamped
    # rows, so earnings left stamped to a failed payout are invisible to every
    # later sweep while the balance still reports the seller as owed them.
    # Released, they simply fall into the next one.
    #
    # Lives here rather than in the flows that call it — core's sweep and any
    # provider's failure webhook — because the association and the status both
    # belong to the payout, and a provider gem should not have to know the
    # invariant to honour it.
    def fail!
      transaction do
        release_transfers
        # The amount stays: an operator investigating a failed settlement has
        # to see what was attempted, and the `owed` scope already excludes it
        # from what is still to be sent.
        update!(status: 'failed')
      end
    end

    # Records that nobody knows whether this settlement happened, and
    # deliberately keeps its earnings claimed.
    #
    # The opposite of {#fail!} in the one way that matters. Releasing here
    # would let the next sweep assemble the same earnings into a second
    # payout, and a provider's idempotency key only protects a retry for as
    # long as the provider keeps the record — Stripe prunes after a day, so a
    # monthly sweep is well past it. Held instead, the earnings stay out of
    # every later sweep until a person or a webhook settles what actually
    # happened.
    def unresolve!
      update!(status: 'unresolved')
    end

    # Hands the earnings back to the next sweep without recording a failure —
    # for a settlement that never had anything to send.
    def release_transfers
      transfers.update_all(payout_id: nil, updated_at: Time.current)
    end
  end
end
