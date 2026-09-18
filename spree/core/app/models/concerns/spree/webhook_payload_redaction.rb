# frozen_string_literal: true

module Spree
  # Keeps single-use credentials out of the persisted webhook delivery log.
  #
  # Some events must carry a live credential to their subscriber — a storefront
  # that owns its transactional emails needs the real password reset token to
  # build the email, and a mobile app needs the payment session client secret to
  # confirm the payment. Delivering those over TLS to a merchant-configured
  # endpoint is intended; keeping a readable copy in
  # `spree_webhook_deliveries.payload` is not, because that column is queryable
  # and is served back through the Admin API delivery log to any key holding
  # `read_webhooks` — a scope an operator may grant precisely because it carries
  # no access to payments or customers.
  #
  # Sensitive values are therefore replaced with {REDACTION_PLACEHOLDER} before
  # the record is written, and re-attached in memory at send time so the
  # outgoing request body is unchanged.
  module WebhookPayloadRedaction
    extend ActiveSupport::Concern

    # Payload keys whose values are live credentials, at any depth under `data`.
    #
    # Payment session secrets are gateway-agnostic: `external_client_secret` is
    # a core column and `external_data` is a free-form provider hash, so every
    # provider that stores a confirmation credential there is covered.
    SENSITIVE_PAYLOAD_KEYS = %w[
      reset_token
      unsubscribe_token
      verification_token
      download_url
      external_client_secret
      client_secret
      ephemeral_key_secret
    ].freeze

    REDACTION_PLACEHOLDER = '[REDACTED]'

    # Separates the segments of a secret's path. Segments are escaped before
    # they are joined, so a key that itself contains the separator still maps
    # to one unambiguous path.
    PATH_SEPARATOR = '.'

    # The root both `data` keys share. A payload is persisted as JSON and read
    # back with string keys, so the symbol and string roots must key their
    # secrets identically or nothing restores after a round trip.
    ROOT_SEGMENT = 'data'

    # Splits a payload into the version safe to persist and the secrets held
    # back from it.
    #
    # @param payload [Hash] the full event payload
    # @return [Array(Hash, Hash)] redacted payload, and the extracted secrets
    #   keyed by their dotted path under `data`
    def self.split(payload)
      secrets = {}

      redacted = transform_data_hashes(payload) do |data|
        redact(data, [ROOT_SEGMENT], secrets)
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
        restore(data, [ROOT_SEGMENT], secrets)
      end
    end

    # Walks a hash replacing sensitive values, recording each one against its
    # path so two secrets sharing a key name (`client_secret` at the top level
    # and inside `external_data`) cannot overwrite one another.
    def self.redact(node, path, secrets)
      if node.is_a?(Array)
        return node.each_with_index.map { |element, index| redact(element, path + [index.to_s], secrets) }
      end
      return node unless node.is_a?(Hash)

      node.to_h do |key, value|
        key_path = path + [key.to_s]

        if sensitive?(key, value)
          secrets[secret_key_for(key_path)] = value
          [key, REDACTION_PLACEHOLDER]
        else
          [key, redact(value, key_path, secrets)]
        end
      end
    end
    private_class_method :redact

    # The mirror of {redact}. Only a slot still holding the placeholder is
    # filled, so a real value the payload carries is never overwritten.
    #
    # Deliveries enqueued before path keying shipped carry secrets under a bare
    # key name. Those only ever came from the top level of `data`, so the
    # fallback is confined there — at depth it would fill every same-named slot
    # in the tree with one secret.
    def self.restore(node, path, secrets)
      if node.is_a?(Array)
        return node.each_with_index.map { |element, index| restore(element, path + [index.to_s], secrets) }
      end
      return node unless node.is_a?(Hash)

      node.to_h do |key, value|
        key_path = path + [key.to_s]
        next [key, restore(value, key_path, secrets)] unless value == REDACTION_PLACEHOLDER

        secret = secrets[secret_key_for(key_path)]
        secret ||= secrets[key.to_s] if path.one?

        [key, secret.presence || value]
      end
    end
    private_class_method :restore

    def self.sensitive?(key, value)
      SENSITIVE_PAYLOAD_KEYS.include?(key.to_s) && value.present? &&
        !value.is_a?(Hash) && !value.is_a?(Array)
    end
    private_class_method :sensitive?

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

    # Secrets are keyed by path alone. They cross an ActiveJob serialization
    # boundary, which coerces symbol keys to strings, so the key form at split
    # time cannot be relied on to still match at merge time.
    #
    # Each segment escapes the separator (and the escape character) before the
    # join, so `['a.b', 'c']` and `['a', 'b', 'c']` stay distinct keys.
    def self.secret_key_for(path)
      path.map { |segment| segment.gsub('\\', '\\\\\\\\').gsub(PATH_SEPARATOR, '\\.') }.join(PATH_SEPARATOR)
    end
    private_class_method :secret_key_for
  end
end
