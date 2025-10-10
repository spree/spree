module Spree
  class Order < Spree.base_class
    module Digital
      # Returns true if all order line items are digital
      #
      # @return [Boolean]
      def digital?
        if line_items.empty?
          false
        else
          line_items.all?(&:digital?)
        end
      end

      # Returns true if any order line item is digital
      #
      # @return [Boolean]
      def some_digital?
        line_items.any?(&:digital?)
      end

      # Returns true if any order line item has digital assets
      #
      # @return [Boolean]
      def with_digital_assets?
        line_items.any?(&:with_digital_assets?)
      end

      # Returns all line items with digital assets
      #
      # @return [Array<Spree::LineItem>]
      def digital_line_items
        line_items.with_digital_assets.distinct
      end

      # Returns all digital links for the order
      #
      # @return [Array<Spree::DigitalLink>]
      def digital_links
        digital_line_items.map(&:digital_links).flatten
      end

      def create_digital_links
        digital_line_items.includes(variant: :digitals).each do |line_item|
          line_item.variant.digitals.each do |digital|
            line_item.digital_links.create!(digital: digital)
          end
        end
      end
    end
  end
end
