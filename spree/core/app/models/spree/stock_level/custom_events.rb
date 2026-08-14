# frozen_string_literal: true

module Spree
  class StockLevel < Spree.base_class
    # Dual-emits the pre-6.0 `stock_item.*` lifecycle events beside the
    # `stock_level.*` ones, so a webhook endpoint a merchant configured against
    # the old names keeps receiving deliveries for one release. Removed in 6.1,
    # the same way {Spree::Fulfillment::CustomEvents} carries `shipment.*`.
    #
    # The twins are written here rather than as an option on
    # {Spree::Publishable} because one rename does not need generic machinery
    # on a concern every Spree model includes — and rather than in the
    # `Spree::StockItem` alias file because that is autoloaded lazily, which
    # would leave the events firing in production and silently not in
    # development.
    module CustomEvents
      LEGACY_EVENT_PREFIX = 'stock_item'
      LEGACY_EVENT_SUFFIXES = %w[created updated deleted].freeze

      # Wraps publishing rather than the three callbacks that call it, so the
      # decisions Publishable makes — whether events are enabled at all,
      # whether a touch-only update is worth announcing — are made once and the
      # legacy twin simply follows whatever the new name did.
      def publish_event(event_name, payload = nil, metadata = {})
        published = super

        legacy_name = legacy_event_name(event_name)
        return published if legacy_name.nil?

        super(legacy_name, payload, metadata)

        published
      end

      private

      # @return [String, nil] the pre-6.0 name for a lifecycle event, or nil
      #   for anything else this model publishes
      def legacy_event_name(event_name)
        prefix, _, suffix = event_name.to_s.rpartition('.')
        return unless prefix == event_prefix
        return unless LEGACY_EVENT_SUFFIXES.include?(suffix)

        "#{LEGACY_EVENT_PREFIX}.#{suffix}"
      end
    end
  end
end
