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
        def sanitize(value)
          case value
          when Hash
            value.to_h.stringify_keys.each_with_object({}) do |(key, nested), result|
              next if key.match?(SECRET_PATTERN) || SECRET_ASSOCIATIONS.include?(key)

              result[key] = sanitize(nested)
            end
          when Array
            value.map { |element| sanitize(element) }
          else
            value
          end
        end

        # @param entry [Spree::AgentTools::ResourceMap::Entry]
        # @param record [ActiveRecord::Base]
        # @return [Hash]
        def call(entry:, record:)
          attributes = serialize(entry, record)
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

        def formatted(value)
          return if value.blank?

          value.to_s
        end
      end
    end
  end
end
