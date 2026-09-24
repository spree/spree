# frozen_string_literal: true

module Spree
  class WebhookDeliveryJob < Spree::BaseJob
    # Raised when the endpoint answered with anything other than 2xx, timed
    # out or could not be reached, so the delivery is sent again with backoff.
    class DeliveryFailed < StandardError; end

    queue_as Spree.queues.webhooks

    # Delivery is retry-safe: each attempt overwrites the outcome on the same
    # delivery record, and receivers deduplicate on the event id.
    retry_on StandardError, wait: :polynomially_longer, attempts: 5
    # The outcome of the last attempt is already on the delivery record, so an
    # exhausted retry is not re-raised into the queue backend.
    retry_on DeliveryFailed, wait: :polynomially_longer, attempts: 5 do |_job, _error|
    end
    # Must come after `retry_on StandardError` so DeserializationError lands in discard
    # (ActiveJob handler lookup is reverse-declaration-order).
    discard_on ActiveJob::DeserializationError

    # Accept optional second argument for backward compatibility with jobs
    # enqueued before this change was deployed.
    #
    # `payload_secrets` carries credentials withheld from the persisted payload
    # so the outgoing request body stays complete. See
    # {Spree::WebhookPayloadRedaction}.
    def perform(delivery_id, _deprecated_secret_key = nil, payload_secrets: nil)
      delivery = Spree::WebhookDelivery.find_by(id: delivery_id)
      return if delivery.nil?

      endpoint = delivery.webhook_endpoint
      return if endpoint.nil?
      # A retry stops once the endpoint was switched off, by hand or by auto-disable.
      return if executions > 1 && !endpoint.active?

      delivery.payload_secrets = payload_secrets
      Spree::Webhooks::DeliverWebhook.call(delivery: delivery, secret_key: endpoint.secret_key)

      raise DeliveryFailed, "Webhook delivery #{delivery.prefixed_id} failed" if delivery.failed?
    end
  end
end
