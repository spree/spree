module Spree
  class Order < Spree.base_class
    module Digital
      def digital?
        if line_items.empty?
          false
        else
          line_items.all?(&:digital?)
        end
      end

      def some_digital?
        line_items.any?(&:digital?)
      end

      def digital_line_items
        line_items.with_digital_assets.distinct
      end

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

      def go_to_payment_if_fully_digital!
        return unless digital?
        return unless delivery?

        next!
      end
    end
  end
end
