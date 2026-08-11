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
      # Always a plain Hash: the integration hands over what the SDK's
      # signature validation parsed from the raw body.
      payload = payload.to_h.deep_stringify_keys
      return unless payload['description'].to_s.start_with?('tracker.')

      tracker = payload['result'] || {}
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

    # The shape {Spree::Fulfillments::UpdateTracking} takes, plus the
    # tracking code the endpoint matches the fulfillment on.
    #
    # @return [Hash]
    def to_update_tracking_arguments
      {
        tracking_code: tracking_code,
        tracking_status: status,
        estimated_delivery_at: estimated_delivery_at,
        delivered_at: delivered_at,
        details: details
      }
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
