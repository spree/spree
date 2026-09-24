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
    #
    # `token` is the guest cart credential (`X-Spree-Token`), which a placed
    # order inherits; with it anyone can read and change the cart.
    SENSITIVE_PAYLOAD_KEYS = %w[
      token
      reset_token
      unsubscribe_token
      verification_token
      download_url
      external_client_secret
      client_secret
      ephemeral_key_secret
    ].freeze

    # A gift card's `code` is what a shopper redeems, so it is spendable by
    # whoever reads it. Only a gift card's own `code` is redacted — promotion,
    # country and channel codes elsewhere in a payload are not credentials.
    GIFT_CARD_CODE_KEY = 'code'
    GIFT_CARD_NODE = 'gift_card'
    GIFT_CARD_EVENT_PREFIX = 'gift_card.'

    REDACTION_PLACEHOLDER = '[REDACTED]'

    # Separates the segments of a secret's path. Segments are escaped before
    # they are joined, so a key that itself contains the separator still maps
    # to one unambiguous path.
    PATH_SEPARATOR = '.'

    # The root both `data` keys share. A payload is persisted as JSON and read
    # back with string keys, so the symbol and string roots must key their
    # secrets identically or nothing restores after a round trip.
    ROOT_SEGMENT = 'data'

    # A path segment escapes the separator so it cannot be read as a boundary,
    # and the escape character itself so the escaping stays reversible.
    PATH_ESCAPES = { '\\' => '\\\\', PATH_SEPARATOR => "\\#{PATH_SEPARATOR}" }.freeze
    PATH_ESCAPES_PATTERN = /[\\#{Regexp.escape(PATH_SEPARATOR)}]/.freeze

    # Splits a payload into the version safe to persist and the secrets held
    # back from it.
    #
    # @param payload [Hash] the full event payload
    # @return [Array(Hash, Hash)] redacted payload, and the extracted secrets
    #   keyed by their dotted path under `data`
    def self.split(payload)
      secrets = {}
      gift_card_event = event_name_of(payload).start_with?(GIFT_CARD_EVENT_PREFIX)

      redacted = transform_data_hashes(payload) do |data|
        redact(data, [ROOT_SEGMENT], secrets, gift_card_event)
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
    def self.redact(node, path, secrets, gift_card_event = false)
      if node.is_a?(Array)
        return node.each_with_index.map { |element, index| redact(element, path + [index.to_s], secrets, gift_card_event) }
      end
      return node unless node.is_a?(Hash)

      node.to_h do |key, value|
        key_path = path + [key.to_s]

        if sensitive?(key, value) || gift_card_code?(key, value, path, gift_card_event)
          secrets[secret_key_for(key_path)] = value
          [key, REDACTION_PLACEHOLDER]
        else
          [key, redact(value, key_path, secrets, gift_card_event)]
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
      SENSITIVE_PAYLOAD_KEYS.include?(key.to_s) && scalar?(value)
    end
    private_class_method :sensitive?

    # The `code` of a gift card: at the root of a gift card event's data, or
    # on a `gift_card` node nested in another record (an order or cart that
    # has one applied).
    def self.gift_card_code?(key, value, path, gift_card_event)
      return false unless key.to_s == GIFT_CARD_CODE_KEY && scalar?(value)
      return true if gift_card_event && path == [ROOT_SEGMENT]

      path.last == GIFT_CARD_NODE
    end
    private_class_method :gift_card_code?

    def self.scalar?(value)
      value.present? && !value.is_a?(Hash) && !value.is_a?(Array)
    end
    private_class_method :scalar?

    def self.event_name_of(payload)
      return '' unless payload.is_a?(Hash)

      (payload[:name] || payload['name']).to_s
    end
    private_class_method :event_name_of

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
      path.map { |segment| segment.gsub(PATH_ESCAPES_PATTERN) { |character| PATH_ESCAPES[character] } }.
        join(PATH_SEPARATOR)
    end
    private_class_method :secret_key_for
  end
end
