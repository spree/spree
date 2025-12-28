# frozen_string_literal: true

module Spree
  # Listens to Spree events and queues webhook deliveries for enabled endpoints.
  #
  # This subscriber listens to all Spree events and for each event, finds
  # all enabled webhook endpoints that are subscribed to that event and queues
  # a delivery job for each one.
  #
  # The event payload is passed through directly without transformation.
  # Events should already be serialized by the EventSerializer.
  #
  # @example
  #   # Webhooks are automatically delivered when events are published
  #   Spree::Events.publish('order.completed', order: order)
  #
  class WebhookEventSubscriber < Spree::Subscriber
    subscribes_to '*'

    def handle(event)
      return unless Spree::Api::Config.webhooks_enabled

      store = Spree::Current.store

      # Find all active endpoints for this store subscribed to this event
      endpoints = Spree::WebhookEndpoint.active.where(store: store).select { |endpoint| endpoint.subscribed_to?(event.name) }

      return if endpoints.empty?

      # Queue delivery for each endpoint
      endpoints.each do |endpoint|
        queue_delivery(endpoint, event)
      end
    rescue StandardError => e
      Rails.logger.error "[Spree Webhooks] Error processing event: #{e.message}"
      Rails.error.report(e)
    end

    private

    def queue_delivery(endpoint, event)
      # Build base payload (without delivery ID)
      payload = build_payload(event)

      # Create delivery record
      delivery = endpoint.webhook_deliveries.create!(
        event_name: event.name,
        payload: payload
      )

      # Add webhook_delivery_id to payload
      delivery.update_column(:payload, payload.merge(webhook_delivery_id: delivery.id))

      # Queue the delivery job
      Spree::WebhookDeliveryJob.perform_later(delivery.id, endpoint.secret_key)
    rescue StandardError => e
      Rails.logger.error "[Spree Webhooks] Error queuing delivery for endpoint #{endpoint.id}: #{e.message}"
      Rails.error.report(e)
    end

    def build_payload(event)
      {
        id: event.id,
        event: event.name,
        created_at: event.created_at.iso8601,
        data: event.payload
      }
    end
  end
end
