module Spree
  module SellerPayouts
    # Settles one seller, in every currency they are owed in.
    #
    # Its own job rather than a loop inside {SweepDueJob}, because settling a
    # seller talks to a payment provider: a marketplace with a few thousand of
    # them would otherwise hold one worker for the whole run, and one slow
    # provider call would delay every seller queued behind it.
    #
    # Deliberately no retry beyond the base job's infrastructure errors: a
    # sweep that half-ran has already claimed its transfers, and re-running is
    # safe only because of that claim, not because the work is repeatable.
    class SweepSellerJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # @param seller_id [Integer]
      def perform(seller_id)
        seller = Spree::Seller.find_by(id: seller_id)
        return if seller.nil?
        return if seller.resolved_payouts_schedule_interval == 'manual'

        currencies_owed(seller).each do |currency|
          next unless due?(seller, currency)

          Spree.seller_payout_sweep_workflow.call(seller: seller, currency: currency)
        end
      end

      private

      # Whether enough time has passed since this seller was last settled in
      # this currency. A seller who has never been paid is due as soon as they
      # have earned anything — their first settlement should not wait a whole
      # period.
      #
      # Asked per currency, because settlements are made per currency. Reading
      # the seller's most recent payout across all of them would let an
      # out-of-band settlement in one currency reset the clock for every other
      # — a monthly seller paid early in dollars would have their euro balance
      # skipped for another month.
      def due?(seller, currency)
        # Failed payouts are excluded: one releases its earnings back to the
        # next sweep, so counting it as a settlement would block the very
        # retry it exists to allow — for a whole interval, with the money
        # sitting owed and unsent.
        settled_at = seller.seller_payouts.where(currency: currency).
                     where.not(status: 'failed').maximum(:created_at)
        return true if settled_at.nil?

        settled_at <= interval_ago(seller.resolved_payouts_schedule_interval)
      end

      def interval_ago(interval)
        case interval
        when 'daily' then 1.day.ago
        when 'weekly' then 1.week.ago
        when 'biweekly' then 2.weeks.ago
        else 1.month.ago
        end
      end

      # Only the currencies this seller actually has earnings waiting in — a
      # marketplace trading in three currencies should not run three sweeps for
      # a seller who sold in one.
      def currencies_owed(seller)
        seller.seller_transfers.unsettled.distinct.pluck(:currency)
      end
    end
  end
end
