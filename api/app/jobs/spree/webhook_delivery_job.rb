# frozen_string_literal: true

module Spree
  class WebhookDeliveryJob < Spree::BaseJob
    queue_as Spree.queues.webhooks

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    # Accept optional second argument for backward compatibility with jobs
    # enqueued before this change was deployed.
    def perform(delivery_id, _deprecated_secret_key = nil)
      delivery = Spree::WebhookDelivery.find_by(id: delivery_id)
      return if delivery.nil?

      secret_key = delivery.webhook_endpoint.secret_key
      Spree::Webhooks::DeliverWebhook.call(delivery: delivery, secret_key: secret_key)
    end
  end
end
