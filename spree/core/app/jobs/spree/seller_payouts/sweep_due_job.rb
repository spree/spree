module Spree
  module SellerPayouts
    # Hands every approved seller to a job of their own.
    #
    # Scheduled daily by the host app (`spree/spree-starter`'s recurring.yml
    # ships the entry). Daily is right whatever a seller's own interval is,
    # since {SweepSellerJob} decides who is actually due: a scheduler cannot
    # express "weekly, but per seller, from whenever that seller was last
    # paid", so the interval logic lives there rather than in a cron
    # expression.
    #
    # This job only fans out. Settling talks to a payment provider, so doing it
    # inline would hold one worker for the whole marketplace and let a single
    # slow provider call delay every seller behind it. Enqueued in batches with
    # plain `ActiveJob.perform_all_later`, which every queue adapter supports —
    # core must not require a particular one.
    #
    # Continuable, because a marketplace with many sellers takes long enough to
    # fan out that a deploy can land mid-run. Without it a restart would begin
    # again at the first store and re-enqueue every seller already handed off;
    # {SweepSellerJob} would mostly no-op on the duplicates, but a marketplace
    # would still pay for the whole fan-out twice and the sweep it does reach
    # is the one that moves money.
    class SweepDueJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.payouts

      # How many jobs are handed to the adapter at a time. Enough to make the
      # round trip worth it, small enough that a marketplace with a hundred
      # thousand sellers never builds one enormous array.
      BATCH_SIZE = 1_000

      def perform
        step :fan_out do |step|
          # Store by store, so each seller is reached through the store that
          # owns them — which is what makes the (store_id, status) index
          # usable. The cursor is the last store handed off rather than the
          # last seller: resuming mid-store would need a second cursor, and
          # re-running one store's fan-out is cheap next to losing the index.
          Spree::Store.where(id: step.cursor..).order(:id).find_each do |store|
            enqueue_sellers_of(store)
            step.advance! from: store.id
          end
        end
      end

      private

      def enqueue_sellers_of(store)
        store.sellers.approved.in_batches(of: BATCH_SIZE) do |sellers|
          ActiveJob.perform_all_later(sellers.ids.map { |id| SweepSellerJob.new(id) })
        end
      end
    end
  end
end
