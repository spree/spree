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

    # Admin auth events carry live credentials (password reset tokens) and have
    # no legitimate external consumer — core delivers those emails itself.
    # Never forward them to webhook endpoints, including '*' subscriptions.
    NON_DELIVERABLE_EVENTS = %w[admin_user.password_reset_requested].freeze

    def handle(event)
      return unless Spree::Api::Config.webhooks_enabled
      return if event.store_id.blank?
      return if NON_DELIVERABLE_EVENTS.include?(event.name)

      # Only load the columns we need for matching and delivery
      endpoints = Spree::WebhookEndpoint
        .enabled
        .where(store_id: event.store_id)
        .select(:id, :subscriptions)

      endpoints.each do |endpoint|
        next unless endpoint.subscribed_to?(event.name)

        queue_delivery(endpoint, event)
      end
    rescue StandardError => e
      Rails.logger.error "[Spree Webhooks] Error processing event: #{e.message}"
      Rails.error.report(e)
    end

    private

    def queue_delivery(endpoint, event)
      payload = build_payload(event)

      # Deduplicate: skip if we already have a delivery for this event + endpoint
      if event.id.present?
        return if Spree::WebhookDelivery.exists?(
          webhook_endpoint_id: endpoint.id,
          event_id: event.id
        )
      end

      # Live credentials go over the wire but never into the delivery log.
      persisted_payload, secrets = Spree::WebhookPayloadRedaction.split(payload)

      delivery = endpoint.webhook_deliveries.create!(
        event_name: event.name,
        event_id: event.id,
        payload: persisted_payload
      )

      Spree::WebhookDeliveryJob.perform_later(delivery.id, payload_secrets: secrets)
    rescue ActiveRecord::RecordNotUnique
      # Race condition: another thread already created this delivery — safe to ignore
    rescue StandardError => e
      Rails.logger.error "[Spree Webhooks] Error queuing delivery for endpoint #{endpoint.id}: #{e.message}"
      Rails.error.report(e)
    end

    def build_payload(event)
      {
        id: event.id,
        name: event.name,
        created_at: event.created_at.iso8601,
        data: event.payload,
        metadata: event.metadata
      }
    end
  end
end
