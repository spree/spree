module Spree
  module Admin
    module AdjustmentsHelper

      def display_adjustable(adjustable)
        case adjustable
          when Spree::LineItem
            display_line_item(adjustable)
          when Spree::Shipment
            display_shipment(adjustable)
          when Spree::Order
            display_order(adjustable)
        end

      end

      private

      def display_line_item(line_item)
        variant = line_item.variant
        parts = []
        parts << variant.product.name
        parts << "(#{variant.options_text})" if variant.options_text.present?
        parts << line_item.display_total
        safe_join(parts, "<br />".html_safe)
      end

      def display_shipment(shipment)
        "#{Spree.t(:shipment)} ##{shipment.number}<br>#{shipment.display_cost}".html_safe
      end

      def display_order(order)
        Spree.t(:order)
      end
    end
  end
end
