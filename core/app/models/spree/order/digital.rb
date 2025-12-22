module Spree
  class Order < Spree.base_class
    module Digital
      # Returns true if all order line items are digital
      #
      # @return [Boolean]
      def digital?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).all?(&:digital?)
        end
      end

      # Returns true if any order line item is digital
      #
      # @return [Boolean]
      def some_digital?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(variant: :product).any?(&:digital?)
        end
      end

      # Returns true if any order line item has digital assets
      #
      # @return [Boolean]
      def with_digital_assets?
        if item_count.zero? || line_items.empty?
          false
        else
          line_items.includes(:variant).any?(&:with_digital_assets?)
        end
      end

      # Returns all line items with digital assets
      #
      # @return [Array<Spree::LineItem>]
      def digital_line_items
        line_items.joins(:variant).with_digital_assets.distinct
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
