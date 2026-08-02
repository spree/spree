module Spree
  module Purchase
    # Digitality predicates over line items, shared by Spree::Cart and
    # Spree::Order (fulfillment-side digital delivery stays order-only in
    # Spree::Order::Digital).
    module DigitalItems
      # @return [Boolean] true when every line item is digital
      def digital?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).all?(&:digital?)
        end
      end

      # @return [Boolean] true when any line item is digital
      def some_digital?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).any?(&:digital?)
        end
      end

      # @return [Boolean] true when any line item has digital assets
      def with_digital_assets?
        if total_quantity.zero? || line_items.empty?
          false
        else
          line_items.includes(:variant).any?(&:with_digital_assets?)
        end
      end

      # @return [ActiveRecord::Relation<Spree::LineItem>]
      def digital_line_items
        line_items.joins(:variant).with_digital_assets.distinct
      end

      # @return [Array<Spree::DigitalLink>]
      def digital_links
        digital_line_items.map(&:digital_links).flatten
      end

      # Whether the customer must choose a delivery option in checkout —
      # shipping and both pickup kinds are chosen; digital fulfillments are
      # created by their provider without a selection. Delivery itself
      # happens for all of them.
      #
      # @return [Boolean]
      def delivery_step_required?
        line_items.any? && !digital?
      end
    end
  end
end
