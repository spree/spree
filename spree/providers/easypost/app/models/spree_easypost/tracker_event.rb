module SpreeEasyPost
  # One `tracker.updated` webhook, translated into the vocabulary
  # Spree::Fulfillments::UpdateTracking speaks.
  #
  # Translating carrier status names is the provider's job precisely so core
  # never learns any one carrier's spelling — EasyPost's own vocabulary happens
  # to be close, but `unknown` and `error` are not the same thing to us, and a
  # future provider's will not line up at all.
  class TrackerEvent
    include ActiveModel::Model
    include ActiveModel::Attributes

    # EasyPost status → Spree tracking status. Anything unlisted is recorded as
    # `unknown` rather than dropped: a merchant looking at a parcel wants to
    # see that something was reported, even if we cannot name it.
    STATUS_MAP = {
      'pre_transit' => 'pre_transit',
      'in_transit' => 'in_transit',
      'out_for_delivery' => 'out_for_delivery',
      'available_for_pickup' => 'available_for_pickup',
      'delivered' => 'delivered',
      'return_to_sender' => 'return_to_sender',
      'failure' => 'failure',
      'cancelled' => 'failure',
      'error' => 'failure',
      'unknown' => 'unknown'
    }.freeze

    attribute :tracking_code, :string
    attribute :status, :string
    attribute :estimated_delivery_at, :datetime
    attribute :delivered_at, :datetime
    attr_accessor :details

    # @param payload [Hash] the webhook body EasyPost posted
    # @return [SpreeEasyPost::TrackerEvent, nil] nil when the payload is not a
    #   tracker update or carries no tracking code to match on
    def self.from_webhook(payload)
      # A webhook body is untrusted input we only ever read, so it is converted
      # wholesale rather than declared field by field — permitting it would
      # imply the values reach a model, and they do not.
      payload = payload.respond_to?(:to_unsafe_h) ? payload.to_unsafe_h : payload
      payload = payload.to_h.deep_stringify_keys
      return unless payload['description'].to_s.start_with?('tracker.')

      tracker = payload['result'] || {}
      tracker = tracker.respond_to?(:to_unsafe_h) ? tracker.to_unsafe_h.deep_stringify_keys : tracker
      tracking_code = tracker['tracking_code']
      return if tracking_code.blank?

      new(
        tracking_code: tracking_code,
        status: STATUS_MAP.fetch(tracker['status'].to_s, 'unknown'),
        estimated_delivery_at: tracker['est_delivery_date'],
        delivered_at: delivery_time(tracker),
        details: tracker.slice('status', 'status_detail', 'carrier', 'est_delivery_date', 'public_url')
      )
    end

    # The scan that actually recorded delivery, which is earlier than the
    # webhook and is what a return window has to run from.
    def self.delivery_time(tracker)
      return unless tracker['status'].to_s == 'delivered'

      delivering_scan = Array(tracker['tracking_details']).reverse.find do |detail|
        detail.is_a?(Hash) && detail['status'].to_s == 'delivered'
      end

      delivering_scan&.dig('datetime')
    end
    private_class_method :delivery_time
  end
end
