# frozen_string_literal: true

module Spree
  class WebhookDeliveryJob < Spree::BaseJob
    queue_as Spree.queues.webhooks

    retry_on StandardError, wait: :polynomially_longer, attempts: 5

    def perform(delivery_id, secret_key)
      delivery = Spree::WebhookDelivery.find_by(id: delivery_id)
      return if delivery.nil?

      Spree::Webhooks::DeliverWebhook.call(delivery: delivery, secret_key: secret_key)
    end
  end
end
