module Spree
  # The status of money a provider moves for a payment: a capture event or a
  # refund. A gateway that answers at once writes `completed`; one that answers
  # `requested?` leaves the row `requested` until its webhook completes or
  # fails it.
  #
  # Rows written before the column existed have no status until the
  # backfill_settlement_statuses upgrade step runs, and read as completed
  # until then, so no sum moves.
  module SettlementStatus
    extend ActiveSupport::Concern

    included do
      include Spree::HasStatus

      has_status :requested, :completed, :failed, default: :completed

      # Money that moved: completed rows and rows not yet backfilled.
      scope :completed_or_unset, -> { where(status: [nil, 'completed']) }
      # Money that moved or may still move, which a balance check reserves.
      scope :not_failed, -> { where(status: nil).or(where.not(status: 'failed')) }
    end

    # @return [String]
    def status
      super.presence || 'completed'
    end
  end
end
