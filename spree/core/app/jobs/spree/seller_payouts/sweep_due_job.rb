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
        Spree::Seller.where(status: 'approved').find_each do |seller|
          next if seller.resolved_payouts_schedule_interval == 'manual'
          next unless due?(seller)

          currencies_owed(seller).each do |currency|
            Spree.seller_payout_sweep_workflow.call(seller: seller, currency: currency)
          end
        end
      end

      private

      # Whether enough time has passed since this seller was last settled.
      # A seller who has never been paid is due as soon as they have earned
      # anything — their first settlement should not wait a whole period.
      def due?(seller)
        last = seller.seller_payouts.order(:created_at).last
        return true if last.nil?

        last.created_at <= interval_ago(seller.resolved_payouts_schedule_interval)
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
