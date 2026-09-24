module Spree
  # Shared base for every Spree job.
  #
  # Retries only transient infrastructure errors. Broad replay is unsafe here because
  # most jobs have non-idempotent post-work side effects (counters, state transitions,
  # lifecycle events, external calls); jobs whose work is retry-safe opt in to
  # `retry_on StandardError` themselves (see `Spree::WebhookDeliveryJob`,
  # `Spree::Events::SubscriberJob`). RecordNotFound gets its own tighter policy
  # to absorb the Sidekiq enqueue-vs-DB-commit race (sub-second window) without
  # holding the queue for genuine deletes.
  class BaseJob < ApplicationJob
    queue_as Spree.queues.default

    retry_on ActiveRecord::Deadlocked,
             ActiveRecord::LockWaitTimeout,
             ActiveRecord::ConnectionNotEstablished,
             ActiveRecord::ConnectionFailed,
             wait: :polynomially_longer, attempts: 5
    retry_on ActiveRecord::RecordNotFound, wait: 2.seconds, attempts: 3

    discard_on ActiveJob::DeserializationError

    private

    # Runs the block once per store owning a record in +records+, inside that
    # store and with +records+ narrowed to it.
    #
    # For installation-wide sweeps. A job has no store of its own, so the work
    # done for a record — its emails, events, store settings — would otherwise
    # run in the default store whichever store the record belongs to.
    # Narrowing the relation keeps each query store-scoped once the store
    # context arms Spree::StoreScopeGuard.
    #
    # @param records [ActiveRecord::Relation] records of a store-owned model
    # @yieldparam store_records [ActiveRecord::Relation] +records+ of one store
    # @return [void]
    def each_store_of(records)
      # Deleted stores too — their records were swept before this was per store.
      Spree::Store.with_deleted.where(id: records.select(:store_id)).find_each do |store|
        Spree::Current.with_store(store) { yield records.where(store_id: store.id) }
      end
    end
  end
end
