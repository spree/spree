module Spree
  # Shared base for every Spree job.
  #
  # Retry policy is intentionally narrow: only transient infrastructure errors
  # (DB deadlocks, lock-wait timeouts, dropped connections, and the Sidekiq
  # enqueue-vs-DB-commit race that surfaces as RecordNotFound) get replayed.
  # We do not `retry_on StandardError` here because broad replay can re-fire
  # post-work side effects (counter increments, state transitions, lifecycle
  # events, external API calls) that aren't idempotent — each job opts into
  # broader retries explicitly when its own side effects are safe to repeat
  # (see `Spree::WebhookDeliveryJob`, `Spree::Events::SubscriberJob`).
  #
  # ActiveJob's handler lookup is reverse-declaration-order, so a subclass that
  # declares `retry_on StandardError` shadows the entries below for any
  # exception it matches — that's the right behavior for jobs whose work is
  # genuinely retry-safe for any failure (network I/O, external services).
  #
  # We intentionally retry — rather than discard — `RecordNotFound`. Sidekiq can
  # start a job before the enqueuing transaction has committed, so an early
  # `find` may raise for a record that exists a moment later. The polynomial
  # backoff covers that window; truly missing records exhaust attempts and
  # land in the dead queue for operator review.
  class BaseJob < ApplicationJob
    queue_as Spree.queues.default

    retry_on ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout,
             ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed,
             ActiveRecord::RecordNotFound,
             wait: :polynomially_longer, attempts: 5

    discard_on ActiveJob::DeserializationError
  end
end
