module Spree
  module FulfillmentProvider
    # Digital delivery: fulfills itself on order completion and generates
    # DigitalLinks idempotently, one per unit of quantity — replacing the
    # legacy non-idempotent checkout callback that created one link per line
    # item regardless of quantity.
    class Digital < Base
      def self.digital?
        true
      end

      def auto_fulfill?
        true
      end

      def requires_address?
        false
      end

      def create_fulfillment(fulfillment)
        fulfillment.line_items.each do |line_item|
          ensure_links_for(line_item)
        end
        {}
      end

      def cancel_fulfillment(_fulfillment)
        true
      end

      # Tops the line item up to one link per asset per unit of quantity.
      # Also used at order completion for physical items carrying digital
      # assets (e.g. a manual with a device) that ship through other providers.
      def ensure_links_for(line_item)
        line_item.variant.digital_assets.each do |digital_asset|
          existing = line_item.digital_links.where(digital_asset: digital_asset).count
          (line_item.quantity - existing).times do
            line_item.digital_links.create!(digital_asset: digital_asset)
          end
        end
      end
    end
  end
end
