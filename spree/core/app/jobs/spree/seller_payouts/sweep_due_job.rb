module Spree
  module SellerPayouts
    # Hands every approved seller to a job of their own.
    #
    # Scheduled by the host app — daily is right, since {SweepSellerJob}
    # decides who is actually due. A scheduler cannot express "weekly, but per
    # seller, from whenever that seller was last paid", so the interval logic
    # lives there rather than in a cron expression.
    #
    # This job only fans out. Settling talks to a payment provider, so doing it
    # inline would hold one worker for the whole marketplace and let a single
    # slow provider call delay every seller behind it. Enqueued in batches with
    # plain `ActiveJob.perform_all_later`, which every queue adapter supports —
    # core must not require a particular one.
    class SweepDueJob < ::Spree::BaseJob
      queue_as Spree.queues.payouts

      # How many jobs are handed to the adapter at a time. Enough to make the
      # round trip worth it, small enough that a marketplace with a hundred
      # thousand sellers never builds one enormous array.
      BATCH_SIZE = 1_000

      def perform
        # Store by store, so each seller is reached through the store that owns
        # them — which is what makes the (store, status) index usable.
        Spree::Store.find_each do |store|
          store.sellers.approved.in_batches(of: BATCH_SIZE) do |sellers|
            ActiveJob.perform_all_later(sellers.ids.map { |id| SweepSellerJob.new(id) })
          end
        end
      end
    end
  end
end
