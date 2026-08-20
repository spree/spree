module Spree
  module Assistant
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

      class << self
        # @param entry [Spree::Assistant::ResourceMap::Entry]
        # @param record [ActiveRecord::Base]
        # @return [Hash]
        def call(entry:, record:)
          attributes = serialize(entry, record)

          {
            id: record.prefixed_id,
            resource: entry.key,
            title: title_for(record, attributes),
            subtitle: subtitle_for(attributes),
            status: attributes['status'],
            image_url: attributes['thumbnail_url'],
            # The dashboard route this record lives at, so the panel links
            # straight to it instead of the merchant hunting for it.
            path: entry.dashboard_path_for(record)
          }.compact
        end

        private

        def serialize(entry, record)
          entry.serializer_class.new(record).to_h.stringify_keys
        rescue StandardError
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

        def subtitle_for(attributes)
          SUBTITLE_FIELDS.filter_map { |field| formatted(attributes[field]) }.first
        end

        def formatted(value)
          return if value.blank?

          value.to_s
        end
      end
    end
  end
end
