module Spree
  module AgentTools
    # Turns a record into the compact shape both the model and the panel read.
    #
    # One shape serves both audiences deliberately: the model needs enough to
    # answer the question, and the panel needs enough to render a row the
    # merchant can click through to. Anything richer belongs in `get_resource`.
    class RecordSummary
      # Fields worth showing beneath the title, in the order they are preferred.
      # Status is deliberately absent — it has its own badge on the row, and
      # repeating it would push out the field that actually adds something.
      SUBTITLE_FIELDS = %w[display_total display_price price email number sku].freeze

      # Anything that looks like a credential is dropped before a record can
      # reach the model. The serializers are supposed to mask these already —
      # this is the second lock, because a serializer that gains a field later
      # would otherwise send live secrets to an AI vendor with no code change
      # here at all.
      SECRET_PATTERN = /(token|secret|password|api_key|access_key|private)/i.freeze

      # Whole associations that are never safe to forward, whatever their
      # serializer happens to expose today. A gift card's code IS the bearer
      # instrument — anyone holding it can spend the balance — and an order
      # serializes its gift card unconditionally, so an order lookup would
      # otherwise hand live codes to the AI vendor and write them into chat
      # history. A plain `code` match is too broad: channels, promotions and
      # commission rates all use `code` as an identifier merchants ask about.
      SECRET_ASSOCIATIONS = %w[gift_card gift_cards].freeze

      # A credential does not always sit under a credential-shaped key. Several
      # serializers expose a URL whose path or query string IS the secret — an
      # invitation's `acceptance_url` carries the token that mints a staff
      # account, a digital link's `download_url` is the customer's purchased
      # file, and a data request's, media's, shipping label's and export's
      # download links all address endpoints that authenticate on the link
      # alone. Matching the key name cannot catch those, so the value is
      # checked too.
      #
      # `Admin::DataRequestSerializer` already deletes its own inherited link
      # for exactly this reason; this generalises that decision to every
      # outbound record, so a serializer that gains such a field later is
      # covered without a change here.
      SECRET_VALUE_PATTERN = /
        [?&](?:token|secret|signature|sig|key)=   # a credential in the query string
        |
        \/(?:accept-invitation|digital_links)\/  # or a path whose segment is the token
      /xi.freeze

      # Keys whose value is a link that authenticates on itself. Named rather
      # than pattern-matched, because a bare `_url` match would also drop the
      # ordinary public URLs merchants ask about (a product's storefront link,
      # a store's domain).
      SECRET_ATTRIBUTES = %w[
        acceptance_url download_url
      ].freeze

      # Attributes a named resource may keep, because on that resource the
      # value is an ordinary authenticated path rather than a link that
      # authenticates on itself.
      #
      # An export's download endpoint runs the Admin API's own scope check
      # and `authorize_resource!`, so the link grants nothing on its own and
      # withholding it only sends the merchant to the dashboard for a file
      # the agent just made for them. Keyed per attribute rather than per
      # resource: exempting a whole record would also release any other
      # credential-shaped field it later gains.
      LINK_SAFE_ATTRIBUTES = { 'exports' => %w[download_url].freeze }.freeze

      class << self
        # Strips credential-shaped keys from a serialized record.
        #
        # Public because it is the ONE filter every outbound record must pass:
        # `get_resource` emits a full serializer hash rather than a summary row,
        # and without this it would bypass the protection entirely.
        #
        # Recursive, because serializers nest: an order carries a gift card, a
        # customer carries addresses. A shallow reject would scrub the top level
        # and hand the vendor whatever sat one layer down, which is the failure
        # this filter exists to prevent.
        #
        # @param attributes [Hash]
        # @return [Hash]
        def sanitize(value, resource = nil)
          case value
          when Hash
            exempt = LINK_SAFE_ATTRIBUTES.fetch(resource.to_s, [])

            value.to_h.stringify_keys.each_with_object({}) do |(key, nested), result|
              link_safe = exempt.include?(key)

              next if key.match?(SECRET_PATTERN) || SECRET_ASSOCIATIONS.include?(key)
              next if SECRET_ATTRIBUTES.include?(key) && !link_safe
              next if credential_value?(nested) && !link_safe

              # Only the record's own keys are exempt. A nested association
              # carries its own rules, so recursion drops the exemption.
              result[key] = sanitize(nested)
            end
          when Array
            # Elements are filtered too, not just hash values: a customer's or
            # order's tags are caller-controlled and serialized as a bare
            # string array, so a tag holding a token-bearing URL would
            # otherwise pass straight through.
            value.reject { |element| credential_value?(element) }.map { |element| sanitize(element) }
          else
            value
          end
        end

        # @param entry [Spree::AgentTools::ResourceMap::Entry]
        # @param record [ActiveRecord::Base]
        # @param attributes [Hash, nil] an already-sanitized serializer hash,
        #   for a caller that needs the full record too — serializing twice
        #   means running every association query twice
        # @return [Hash]
        def call(entry:, record:, attributes: nil)
          attributes ||= serialize(entry, record)
          title = title_for(record, attributes)

          {
            id: record.prefixed_id,
            resource: entry.key,
            title: title,
            subtitle: subtitle_for(attributes, title),
            status: attributes['status'],
            image_url: attributes['thumbnail_url'],
            # The dashboard route this record lives at, so the panel links
            # straight to it instead of the merchant hunting for it.
            path: entry.dashboard_path_for(record)
          }.compact
        end

        private

        # Whether a value is itself a credential — a link that authenticates on
        # nothing but the link.
        def credential_value?(value)
          value.is_a?(String) && value.match?(SECRET_VALUE_PATTERN)
        end

        def serialize(entry, record)
          sanitize(entry.serializer_class.new(record).to_h)
        rescue StandardError => e
          Rails.logger.warn("[Spree] #{entry.key} serializer failed: #{e.class}: #{e.message}")
          {}
        end

        def title_for(record, attributes)
          attributes['name'].presence ||
            attributes['number'].presence ||
            attributes['email'].presence ||
            record.try(:name).presence ||
            record.try(:number).presence ||
            record.to_s
        end

        def subtitle_for(attributes, title)
          value = SUBTITLE_FIELDS.filter_map { |field| formatted(attributes[field]) }.first
          # A subtitle that repeats the title (a customer whose name IS their
          # email) is a wasted line.
          value unless value == title
        end

        # A subtitle is one short line a model reads aloud, so only a scalar
        # will do. A variant's `price` serializes as an object, and `to_s` on
        # it printed the whole Ruby hash — amount, currency, cents and all —
        # where "£89.99" belonged.
        def formatted(value)
          return if value.blank?
          return unless value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Symbol)

          value.to_s
        end
      end
    end
  end
end
