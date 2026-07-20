# frozen_string_literal: true

module Spree
  # Keeps single-use credentials out of the persisted webhook delivery log.
  #
  # Some events must carry a live credential to their subscriber — a storefront
  # that owns its transactional emails needs the real password reset token to
  # build the email. Delivering it over TLS to a merchant-configured endpoint is
  # intended; keeping a readable copy in `spree_webhook_deliveries.payload` is
  # not, because that column is queryable and is served back through the Admin
  # API delivery log.
  #
  # Sensitive values are therefore replaced with {REDACTION_PLACEHOLDER} before
  # the record is written, and re-attached in memory at send time so the
  # outgoing request body is unchanged.
  module WebhookPayloadRedaction
    extend ActiveSupport::Concern

    # Payload keys under `data` whose values are live credentials.
    SENSITIVE_PAYLOAD_KEYS = %w[reset_token unsubscribe_token].freeze

    REDACTION_PLACEHOLDER = '[REDACTED]'

    # Splits a payload into the version safe to persist and the secrets held
    # back from it.
    #
    # @param payload [Hash] the full event payload
    # @return [Array(Hash, Hash)] redacted payload, and the extracted secrets
    #   keyed as they appeared under `data`
    def self.split(payload)
      secrets = {}

      redacted = transform_data_hashes(payload) do |data|
        data.to_h do |key, value|
          if SENSITIVE_PAYLOAD_KEYS.include?(key.to_s) && value.present?
            secrets[secret_key_for(key)] = value
            [key, REDACTION_PLACEHOLDER]
          else
            [key, value]
          end
        end
      end

      secrets.empty? ? [payload, {}] : [redacted, secrets]
    end

    # Re-attaches previously extracted secrets to a redacted payload.
    #
    # @param payload [Hash] the redacted payload
    # @param secrets [Hash] secrets returned by {split}
    # @return [Hash] the payload as it should go over the wire
    def self.merge(payload, secrets)
      return payload if secrets.blank?

      transform_data_hashes(payload) do |data|
        data.to_h do |key, value|
          secret = secrets[secret_key_for(key)]
          [key, secret.presence || value]
        end
      end
    end

    # Applies +block+ to every `data` hash on the payload.
    #
    # Both key forms are visited rather than only the first match: a payload
    # carrying `:data` *and* `'data'` would otherwise leave one of them
    # unredacted.
    def self.transform_data_hashes(payload)
      return payload unless payload.is_a?(Hash)

      [:data, 'data'].reduce(payload) do |result, data_key|
        data = result[data_key]
        next result unless data.is_a?(Hash)

        result.merge(data_key => yield(data))
      end
    end
    private_class_method :transform_data_hashes

    # Secrets are keyed by name alone. They cross an ActiveJob serialization
    # boundary, which coerces symbol keys to strings, so the key form at split
    # time cannot be relied on to still match at merge time.
    def self.secret_key_for(key)
      key.to_s
    end
    private_class_method :secret_key_for
  end
end
