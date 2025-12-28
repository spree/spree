# frozen_string_literal: true

module Spree
  class WebhookDelivery < Spree.base_class
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

    # Mark delivery as completed with HTTP response
    #
    # @param response_code [Integer] HTTP response code
    # @param execution_time [Integer] time in milliseconds
    # @param response_body [String] response body from the webhook endpoint
    def complete!(response_code: nil, execution_time:, error_type: nil, request_errors: nil, response_body: nil)
      update!(
        response_code: response_code,
        execution_time: execution_time,
        error_type: error_type,
        request_errors: request_errors,
        response_body: response_body,
        success: response_code.present? && response_code.to_s.start_with?('2'),
        delivered_at: Time.current
      )
    end
  end
end
