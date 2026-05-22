module Spree
  module Imports
    # Shared base for every job in the imports pipeline.
    #
    # Retry policy is intentionally narrow: only transient infrastructure errors
    # (DB deadlocks, lock-wait timeouts, dropped connections) are replayed. Broad
    # `retry_on StandardError` would replay jobs whose post-work side effects
    # (counter increments, state transitions, lifecycle events) had already
    # partially fired, breaking idempotency. Per-row business errors are caught
    # inside `Spree::ImportRow#process!` and converted to `row.fail!`, so they
    # never bubble up to the job layer.
    #
    # Subclasses may extend the retry list (e.g. `CreateCategoriesJob` adds
    # `RecordNotUnique` to recover from concurrent-import taxon creation races).
    #
    # We intentionally do NOT `discard_on ActiveRecord::RecordNotFound`: Sidekiq is
    # known to start a job before the enqueuing transaction has committed, so an
    # early `find` can raise `RecordNotFound` for a record that will exist a moment
    # later. Letting the job retry covers that window.
    class BaseJob < Spree::BaseJob
      queue_as Spree.queues.imports

      retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
               ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
               ActiveRecord::RecordNotFound,
               wait: :polynomially_longer, attempts: 5

      discard_on ActiveJob::DeserializationError
    end
  end
end
