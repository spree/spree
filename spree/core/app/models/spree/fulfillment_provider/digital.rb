module Spree
  module FulfillmentProvider
    # Digital delivery: fulfills itself on order completion and generates
    # DigitalLinks idempotently, one per unit of quantity — replacing the
    # legacy non-idempotent checkout callback that created one link per line
    # item regardless of quantity.
    class Digital < Base
      def auto_fulfill?
        true
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

      # Tops the line item up to one link per digital per unit of quantity.
      # Also used at order completion for physical items carrying digital
      # assets (e.g. vinyl + download code) that ship through other providers.
      def ensure_links_for(line_item)
        line_item.variant.digitals.each do |digital|
          existing = line_item.digital_links.where(digital: digital).count
          (line_item.quantity - existing).times do
            line_item.digital_links.create!(digital: digital)
          end
        end
      end
    end
  end
end
