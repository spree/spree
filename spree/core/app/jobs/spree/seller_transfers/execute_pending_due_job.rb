module Spree
  module SellerTransfers
    # Hands every seller holding an unconfirmed earning to a job of their own.
    #
    # The transfer level's counterpart to {Spree::SellerPayouts::SweepDueJob},
    # and deliberately a separate schedule rather than something the settlement
    # run does on its way past. The two answer different questions on different
    # clocks: a settlement waits for the seller's own interval, which a
    # marketplace measures in weeks, while an earning the provider refused is
    # owed *now* and the refusal is usually a passing thing — a platform
    # balance that has not settled, a rate limit, a charge not yet usable as a
    # funding source. Run this hourly and that earning clears within the hour;
    # tie it to the settlement run and it waits for the next one.
    #
    # Only sellers who actually have something outstanding are enqueued. The
    # awaiting set is the exception rather than the rule, so on a healthy
    # marketplace this fans out to nobody.
    #
    # Scheduled by the host app, like every other recurring job in core.
    class ExecutePendingDueJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # How many jobs are handed to the adapter at a time, matching the
      # settlement enumerator.
      BATCH_SIZE = 1_000

      def perform
        # Store by store, so each seller is reached through the store that owns
        # them and the provider question below is asked of the right one.
        Spree::Store.find_each do |store|
          sellers_awaiting_provider(store).in_batches(of: BATCH_SIZE) do |sellers|
            ActiveJob.perform_all_later(sellers.ids.map { |id| ExecutePendingJob.new(id) })
          end
        end
      end

      private

      # @param store [Spree::Store]
      # @return [ActiveRecord::Relation<Spree::Seller>]
      def sellers_awaiting_provider(store)
        scope = store.sellers.approved.
                where(id: Spree::SellerTransfer.for_store(store).awaiting_provider.select(:seller_id))

        # A seller the provider will not accept yet keeps their earnings
        # unconfirmed, and the job would return at once. Skipped rather than
        # enqueued, because a marketplace's half-onboarded sellers are a
        # standing population and this runs often — and nothing is lost by it:
        # finishing onboarding runs the job for them directly.
        return scope unless store.payout_provider_class.requires_payout_account?

        scope.where.not(payouts_enabled_at: nil)
      end
    end
  end
end
