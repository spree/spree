# frozen_string_literal: true

module Spree
  class WebhookDelivery < Spree.base_class
    has_prefix_id :whd

    # Raised by {#redeliver!} for a delivery that cannot be sent again.
    class RedeliveryNotAllowed < StandardError; end

    belongs_to :webhook_endpoint, class_name: 'Spree::WebhookEndpoint'
    delegate :url, to: :webhook_endpoint

    # Credentials stripped from the persisted payload. Never written to the
    # database — held in memory on a single delivery instance, assigned by
    # WebhookDeliveryJob when it runs. See {Spree::WebhookPayloadRedaction}.
    attr_accessor :payload_secrets

    validates :event_name, presence: true
    validates :payload, presence: true

    ERROR_TYPES = %w[timeout connection_error].freeze

    scope :successful, -> { where(success: true) }
    scope :failed, -> { where(success: false) }
    scope :pending, -> { where(delivered_at: nil) }
    scope :recent, -> { order(created_at: :desc) }
    scope :for_event, ->(event_name) { where(event_name: event_name) }

    # Ransack configuration
    self.whitelisted_ransackable_attributes = %w[event_name response_code execution_time success delivered_at created_at]

    # Event subjects whose permission is not found by class name alone.
    PAYLOAD_SUBJECT_CLASSES = {
      'cart' => 'Spree::Order',
      'customer' => -> { Spree.customer_class },
      'newsletter_subscriber' => -> { Spree.customer_class }
    }.freeze

    # Event subjects whose payload holds no record of anyone's data.
    PUBLIC_PAYLOAD_SUBJECTS = %w[webhook].freeze

    # The catalog key a caller needs to read this delivery's payload. The
    # payload is the full record the event is about — an order's addresses, a
    # customer's email — so reading the log is no wider than reading the
    # record. A subject no permission scope covers falls back to customer
    # access, since an unknown payload may hold personal data.
    #
    # @return [String, nil] nil when anyone who can read the log may see it
    def payload_permission_key
      subject = event_name.to_s.split('.').first.to_s
      return if PUBLIC_PAYLOAD_SUBJECTS.include?(subject)

      source = PAYLOAD_SUBJECT_CLASSES[subject]
      klass = source.respond_to?(:call) ? source.call : (source || "Spree::#{subject.camelize}").to_s.safe_constantize
      scope = Spree.permissions.scope_for_resource(klass)

      scope ? "read_#{scope.name}" : 'read_customers'
    end

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

    # Payload as it should be sent over the wire.
    #
    # Re-attaches any credentials withheld from the persisted column. Automatic
    # retries of the same delivery keep them, because they travel with the job
    # arguments. Once the job is gone those secrets are gone for good, so a
    # delivery whose payload was redacted cannot be redelivered by hand — see
    # {#redeliverable?}.
    #
    # This is deliberate: keeping a recoverable copy would put the credential
    # back at rest, which is what redaction exists to prevent. The credentials
    # are single-use or short-lived anyway (a password reset token, a payment
    # session client secret); the customer requests a new reset or starts a
    # new payment, which mints a fresh one and a fresh event.
    #
    # @return [Hash]
    def deliverable_payload
      Spree::WebhookPayloadRedaction.merge(payload, payload_secrets)
    end

    # Whether {#redeliver!} can send this delivery again. False when the
    # payload had credentials withheld from the log: resending it would hand
    # the endpoint `[REDACTED]` in place of a usable token.
    #
    # @return [Boolean]
    def redeliverable?
      !Spree::WebhookPayloadRedaction.redacted?(payload)
    end

    # Create a new delivery with the same payload and queue it.
    # Used to retry failed deliveries manually.
    #
    # @raise [RedeliveryNotAllowed] when the payload had credentials redacted
    # @return [Spree::WebhookDelivery] the new delivery
    def redeliver!
      raise RedeliveryNotAllowed, Spree.t(:webhook_delivery_redacted_payload_not_redeliverable) unless redeliverable?

      # A delivery written before payload redaction shipped still holds its
      # credentials in the column. Split them off so the new row is stored
      # redacted, and send them with the job like any fresh delivery.
      persisted_payload, secrets = Spree::WebhookPayloadRedaction.split(payload)

      new_delivery = webhook_endpoint.webhook_deliveries.create!(
        event_name: event_name,
        event_id: nil, # new delivery, not a duplicate
        payload: persisted_payload
      )

      new_delivery.queue_for_delivery!(payload_secrets: secrets)
      new_delivery
    end

    # Queue this delivery for processing.
    # Resolves the job class dynamically since it lives in the api gem.
    #
    # @param payload_secrets [Hash, nil] credentials withheld from the payload
    def queue_for_delivery!(payload_secrets: nil)
      job = 'Spree::WebhookDeliveryJob'.constantize
      payload_secrets.present? ? job.perform_later(id, payload_secrets: payload_secrets) : job.perform_later(id)
    end
  end
end
