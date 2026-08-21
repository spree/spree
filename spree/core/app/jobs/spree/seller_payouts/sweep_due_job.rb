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
        # Preloaded because the schedule falls back to the store's default, so
        # every seller would otherwise reload its own.
        Spree::Seller.where(status: 'approved').includes(:store).find_each do |seller|
          next if seller.resolved_payouts_schedule_interval == 'manual'

          currencies_owed(seller).each do |currency|
            next unless due?(seller, currency)

            Spree.seller_payout_sweep_workflow.call(seller: seller, currency: currency)
          end
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
        settled_at = seller.seller_payouts.where(currency: currency).maximum(:created_at)
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
