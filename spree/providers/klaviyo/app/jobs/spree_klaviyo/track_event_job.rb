module SpreeKlaviyo
  # Records one Klaviyo event for a Spree record.
  class TrackEventJob < BaseJob
    METRICS = %w[placed_order ordered_product fulfilled_order canceled_order return_refunded].freeze

    # @param integration [Spree::Integrations::Klaviyo]
    # @param record [Spree::Order, Spree::OrderGroup, Spree::LineItem, Spree::Fulfillment, Spree::Return]
    # @param metric [String] one of {METRICS}
    # @param notify_customer [Boolean, nil] the Spree event's notify_customer, for
    #   Placed Order, Canceled Order and Fulfilled Order
    # @param event_id [String, nil] the Spree event's id, for Return Refunded
    # @param published_at [Time, nil] when the Spree event was published, for Return Refunded
    def perform(integration, record, metric, notify_customer: true, event_id: nil, published_at: nil)
      raise ArgumentError, "Unknown Klaviyo metric: #{metric}" unless METRICS.include?(metric)

      metric_event = build_event(record, metric, notify_customer, event_id, published_at)
      return if tombstone?(metric_event.email)

      integration.create_event(metric_event)
    end

    private

    def build_event(record, metric, notify_customer, event_id, published_at)
      case metric
      when 'placed_order' then SpreeKlaviyo::MetricEvent.placed_order(record, notify_customer: notify_customer)
      when 'ordered_product' then SpreeKlaviyo::MetricEvent.ordered_product(record)
      when 'fulfilled_order' then SpreeKlaviyo::MetricEvent.fulfilled_order(record, notify_customer: notify_customer)
      when 'canceled_order' then SpreeKlaviyo::MetricEvent.canceled_order(record, notify_customer: notify_customer)
      when 'return_refunded'
        SpreeKlaviyo::MetricEvent.return_refunded(record, event_id: event_id, published_at: published_at)
      end
    end
  end
end
