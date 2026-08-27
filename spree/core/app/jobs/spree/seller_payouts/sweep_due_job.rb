module Spree
  module SellerPayouts
    # Settles every seller whose schedule has come round.
    #
    # Scheduled by the host app — daily is right, since the job itself decides
    # who is actually due. A scheduler cannot express "weekly, but per seller,
    # from whenever that seller was last paid", so the interval logic lives
    # here rather than in a cron expression.
    #
    # Deliberately no retry beyond the base job's infrastructure errors: a
    # sweep that half-ran has already claimed its transfers, and re-running is
    # safe only because of that claim, not because the work is repeatable.
    class SweepDueJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      def perform
        # Store by store, so each seller is reached through the store that owns
        # them — which is what makes the (store, status) index usable, and what
        # the schedule falls back to anyway.
        Spree::Store.find_each do |store|
          store.sellers.approved.find_each { |seller| sweep_seller(seller) }
        end
      end

      private

      # One seller's failure must not end the run for everyone behind them.
      def sweep_seller(seller)
        return if seller.resolved_payouts_schedule_interval == 'manual'

        currencies_owed(seller).each do |currency|
          next unless due?(seller, currency)

          Spree.seller_payout_sweep_workflow.call(seller: seller, currency: currency)
        end
      rescue StandardError => e
        Rails.error.report(e, handled: true, context: { seller_id: seller.id }, source: 'spree.core')
      end

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
