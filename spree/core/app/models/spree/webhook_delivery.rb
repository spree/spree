# frozen_string_literal: true

module Spree
  class WebhookDelivery < Spree.base_class
    has_prefix_id :whd

    belongs_to :webhook_endpoint, class_name: 'Spree::WebhookEndpoint'
    delegate :url, to: :webhook_endpoint

    validates :event_name, presence: true
    validates :payload, presence: true

    ERROR_TYPES = %w[timeout connection_error].freeze

    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }
    scope :pending, -> { where(delivered_at: nil) }
    scope :recent, -> { order(created_at: :desc) }
    scope :for_event, ->(event_name) { where(event_name: event_name) }

    # Ransack configuration
    self.whitelisted_ransackable_attributes = %w[event_name response_code execution_time success delivered_at]

    # Check if the delivery was successful
    #
    # @return [Boolean]
    def successful?
      success == true
    end

    # Check if the delivery failed
    #
    # @return [Boolean]
    def failed?
      success == false
    end

    # Check if the delivery is pending
    #
    # @return [Boolean]
    def pending?
      delivered_at.nil?
    end

    # Mark delivery as completed with HTTP response.
    # Triggers auto-disable check on the endpoint after failures.
    #
    # @param response_code [Integer] HTTP response code
    # @param execution_time [Integer] time in milliseconds
    # @param response_body [String] response body from the webhook endpoint
    def complete!(response_code: nil, execution_time:, error_type: nil, request_errors: nil, response_body: nil)
      is_success = response_code.present? && response_code.to_s.start_with?('2')

      update!(
        response_code: response_code,
        execution_time: execution_time,
        error_type: error_type,
        request_errors: request_errors,
        response_body: response_body,
        success: is_success,
        delivered_at: Time.current
      )

      webhook_endpoint.check_auto_disable! unless is_success
    end

    # Create a new delivery with the same payload and queue it.
    # Used to retry failed deliveries manually.
    #
    # @return [Spree::WebhookDelivery] the new delivery
    def redeliver!
      new_delivery = webhook_endpoint.webhook_deliveries.create!(
        event_name: event_name,
        event_id: nil, # new delivery, not a duplicate
        payload: payload
      )

      new_delivery.queue_for_delivery!
      new_delivery
    end

    # Queue this delivery for processing.
    # Resolves the job class dynamically since it lives in the api gem.
    def queue_for_delivery!
      'Spree::WebhookDeliveryJob'.constantize.perform_later(id)
    end
  end
end
