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
  end
end
